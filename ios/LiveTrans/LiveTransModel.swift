import Foundation
import Combine
@preconcurrency import CoreMedia
import LiveTransCore

@MainActor
final class LiveTransModel: ObservableObject {
    @Published var sessionState: TranslationSessionState
    @Published var onboardingState: OnboardingState
    @Published var captionState: CaptionState = .idle
    @Published var captionShown = false
    @Published var captureActive = false

    private let onDeviceTranslator = AppleOnDeviceTranslator()
    private let visionOCR = VisionOCRService()
    private let decoder = VideoDecoder()
    private let compositor = CaptionCompositor()
    private let loopback = LoopbackServer()

    private var pipeline: TranslationPipeline<OCRFrame>?
    private weak var pipHost: PiPHostViewController?

    private let session: TranslationSession
    private let onboarding: OnboardingFlow
    private let coordinator: TranslationSessionCoordinator

    init(pipHost: PiPHostViewController? = nil) {
        let sessionPersistence = UserDefaultsSessionPersistence()
        let onboardingPersistence = UserDefaultsOnboardingPersistence()
        let quotaStorage = UserDefaultsQuotaStorage()

        let session = TranslationSession(persistence: sessionPersistence)
        let onboarding = OnboardingFlow(persistence: onboardingPersistence)
        let coordinator = TranslationSessionCoordinator(
            session: session,
            onboarding: onboarding,
            standbyPolicy: CaptureStandbyPolicy()
        )
        self.session = session
        self.onboarding = onboarding
        self.coordinator = coordinator
        self.pipHost = pipHost
        sessionState = session.state
        onboardingState = onboarding.state

        session.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.sessionState = state
            }
        }
        onboarding.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.onboardingState = state
            }
        }
        coordinator.onCaptureActivityChange = { [weak self] activity in
            Task { @MainActor in
                self?.captureActive = activity == .active
            }
        }

        pipeline = makePipeline(
            onDevice: onDeviceTranslator,
            credentialStore: PapagoCredentialStore(),
            quotaStorage: quotaStorage
        )
        wirePipeline(coordinator: coordinator, pipeline: pipeline!)
        wireLoopback(coordinator: coordinator, pipeline: pipeline!)
    }

    func toggle() {
        coordinator.toggle()
    }

    func completeOnboarding() {
        coordinator.completeOnboarding()
    }

    func snapshotCaptionFrame() -> CGRect {
        CGRect(x: 0.02, y: 0.82, width: 0.96, height: 0.10)
    }

    func manualSource(_ language: Language) {
        pipeline?.manualSourceLanguage = language
    }

    private func makePipeline(
        onDevice: AppleOnDeviceTranslator,
        credentialStore: PapagoCredentialStore,
        quotaStorage: UserDefaultsQuotaStorage
    ) -> TranslationPipeline<OCRFrame> {
        let visionOCR = self.visionOCR
        let quotaTracker = TranslationQuotaTracker(storage: quotaStorage)
        let cascade = zlotyTranslationCascade(
            onDevice: onDevice,
            quotaTracker: quotaTracker,
            credentialStore: credentialStore
        )
        return TranslationPipeline(
            changeDetector: ChangeDetector(),
            languageDetector: HeuristicSourceLanguageDetector(),
            ocr: { frame in
                try await visionOCR.recognize(frame)
            },
            translator: { text, language in
                try await onDevice.translate(text, from: language, to: .korean)
            },
            filter: ScreenTextFilter(),
            cascadeTranslator: cascade,
            inPlaceModeDecider: InPlaceModeDecider(),
            inPlaceLayoutEngine: InPlaceLayoutEngine()
        )
    }

    private func zlotyTranslationCascade(
        onDevice: AppleOnDeviceTranslator,
        quotaTracker: TranslationQuotaTracker,
        credentialStore: PapagoCredentialStore
    ) -> CascadeTranslator {
        let papago: PapagoTranslating
        if let credentials = credentialStore.load(),
           !credentials.clientID.isEmpty,
           !credentials.clientSecret.isEmpty {
            papago = PapagoHTTPClient(clientID: credentials.clientID, clientSecret: credentials.clientSecret)
        } else {
            papago = UnavailablePapagoClient()
        }
        return CascadeTranslator(
            onDevice: { text, language in
                try await onDevice.translate(text, from: language, to: .korean)
            },
            papago: papago,
            quotaTracker: quotaTracker,
            isNetworkAvailable: { await NetworkAvailabilityMonitor.isAvailable() }
        )
    }

    private func wirePipeline(coordinator: TranslationSessionCoordinator, pipeline: TranslationPipeline<OCRFrame>) {
        pipeline.onCaptionStateChange = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                self.captionState = state
                self.renderCaption(state)
            }
        }
        pipeline.onCascadeEvent = { [weak self] _ in
            Task { @MainActor in
                self?.captionShown = true
            }
        }
    }

    private func wireLoopback(coordinator: TranslationSessionCoordinator, pipeline: TranslationPipeline<OCRFrame>) {
        loopback.onSampleBuffer = { [weak self] sampleBuffer in
            Task { @MainActor in
                guard let self else { return }
                await self.handleFrame(sampleBuffer, coordinator: coordinator, pipeline: pipeline)
            }
        }
        loopback.onFormatDescription = { [weak self] formatDescription in
            Task { @MainActor in
                self?.pipHost?.noteFormatDescription(formatDescription)
            }
        }
    }

    func startCapture(port: UInt16 = 19_642) throws {
        try loopback.start(port: port)
    }

    func stopCapture() {
        loopback.stop()
    }

    func enqueueToPiP(_ sampleBuffer: CMSampleBuffer) {
        pipHost?.enqueue(sampleBuffer)
    }

    func setPiPHost(_ host: PiPHostViewController?) {
        pipHost = host
        host?.onTogglePlayback = { [weak self] playing in
            Task { @MainActor in
                guard let self else { return }
                if playing {
                    self.pipeline?.resume()
                } else {
                    self.pipeline?.pause()
                }
            }
        }
        host?.isPlaybackPaused = { [weak self] in
            self?.pipeline?.isPaused ?? false
        }
    }

    private func handleFrame(
        _ sampleBuffer: CMSampleBuffer,
        coordinator: TranslationSessionCoordinator,
        pipeline: TranslationPipeline<OCRFrame>
    ) async {
        guard captureActive else { return }

        guard let decoded = await decoder.decode(sampleBuffer) else { return }
        let composed = compositor.composite(decoded)
        let toDisplay = composed ?? decoded
        enqueueToPiP(toDisplay)

        guard let cgImage = FrameFingerprinter.cgImage(from: decoded) else { return }
        let fingerprint = FrameFingerprinter.fingerprint(cgImage: cgImage)
        let activity = coordinator.observeScreen(fingerprint: fingerprint, at: Date())
        guard activity == .active else { return }

        let frame = OCRFrame(cgImage: cgImage, fingerprint: fingerprint)
        let screen = CapturedScreen(fingerprint: fingerprint, capturedAt: Date(), payload: frame)
        await pipeline.process(screen)
    }

    private func renderCaption(_ state: CaptionState) {
        switch state {
        case .ready(let blocks):
            guard let first = blocks.first else {
                captionShown = false
                compositor.clear()
                return
            }
            let rect = snapshotCaptionFrame()
            compositor.update(line: first.translatedText, in: rect)
            captionShown = true
        case .inPlaceReady(let layout):
            for placement in layout.placements {
                let rect = CGRect(
                    x: placement.placementRect.x,
                    y: placement.placementRect.y,
                    width: placement.placementRect.width,
                    height: placement.placementRect.height
                )
                compositor.update(line: placement.translatedText, in: rect)
            }
            captionShown = true
        case .preparing:
            let rect = snapshotCaptionFrame()
            compositor.update(line: "준비 중...", in: rect)
            captionShown = true
        case .failed:
            let rect = snapshotCaptionFrame()
            compositor.update(line: "번역 실패", in: rect)
            captionShown = true
        case .needsSourceSelection:
            let rect = snapshotCaptionFrame()
            compositor.update(line: "원문 언어 선택 필요", in: rect)
            captionShown = true
        case .idle:
            captionShown = false
            compositor.clear()
        }
    }
}

private struct UnavailablePapagoClient: PapagoTranslating {
    func translate(
        _ text: String,
        from source: Language,
        to target: TargetLanguage
    ) async throws -> String {
        throw PapagoError.httpError
    }
}