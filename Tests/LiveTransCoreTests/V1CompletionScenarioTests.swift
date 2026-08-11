import Foundation
import Testing
import LiveTransCore

@Suite
struct V1CompletionScenarioTests {
    private struct Payload: Sendable {
        let blocks: [ScreenTextBlock]
    }

    private final class StateSink: @unchecked Sendable {
        var states: [CaptionState] = []
        var cascadeEvents: [CascadeEvent] = []
    }

    private struct Harness {
        let session: TranslationSession
        let coordinator: TranslationSessionCoordinator
        let pipeline: TranslationPipeline<Payload>
        let sink: StateSink
        let papago: StubPapagoTranslator
    }

    private func makeHarness() -> Harness {
        let session = TranslationSession(persistence: InMemoryTranslationSessionPersistence())
        let onboarding = OnboardingFlow(persistence: InMemoryOnboardingPersistence())
        let coordinator = TranslationSessionCoordinator(session: session, onboarding: onboarding)

        let sink = StateSink()
        let papago = StubPapagoTranslator(result: "Papago 번역")
        let cascade = CascadeTranslator(
            onDevice: { text, _ in "온디바이스 \(text)" },
            papago: papago,
            quotaTracker: TranslationQuotaTracker(
                dailyLimit: 10_000,
                storage: InMemoryTranslationQuotaStore(),
                calendar: Calendar(identifier: .gregorian)
            )
        )
        let decider = InPlaceModeDecider(embeddedBlockThreshold: 1, embeddedShareThreshold: 0.5)
        let pipeline = TranslationPipeline<Payload>(
            changeDetector: ChangeDetector(),
            languageDetector: HeuristicSourceLanguageDetector(),
            ocr: { $0.blocks },
            translator: { text, language in
                "[\(language)] \(text)"
            },
            cascadeTranslator: cascade,
            inPlaceModeDecider: decider,
            inPlaceLayoutEngine: InPlaceLayoutEngine()
        )
        pipeline.onCaptionStateChange = { sink.states.append($0) }
        pipeline.onCascadeEvent = { sink.cascadeEvents.append($0) }

        return Harness(
            session: session,
            coordinator: coordinator,
            pipeline: pipeline,
            sink: sink,
            papago: papago
        )
    }

    private func screen(
        _ blocks: [ScreenTextBlock],
        fingerprint: String,
        at timeInterval: TimeInterval = 1000
    ) -> CapturedScreen<Payload> {
        CapturedScreen(
            fingerprint: fingerprint,
            capturedAt: Date(timeIntervalSince1970: timeInterval),
            payload: Payload(blocks: blocks)
        )
    }

    private func webBlock(_ text: String) -> ScreenTextBlock {
        ScreenTextBlock(
            text: text,
            rect: NormalizedRect(x: 0.05, y: 0.2, width: 0.9, height: 0.1)
        )
    }

    private func webtoonBlock(_ text: String, y: Double) -> ScreenTextBlock {
        ScreenTextBlock(
            text: text,
            rect: NormalizedRect(x: 0.1, y: y, width: 0.5, height: 0.08),
            kind: .embedded
        )
    }

    @Test("첫 실행 → 온보딩 → 웹 텍스트 캡션 → 웹툰 제자리 → 토글 off")
    func fullV1Journey() async throws {
        let harness = makeHarness()

        #expect(harness.coordinator.onboarding.needsOnboarding)
        harness.coordinator.toggle()
        #expect(harness.session.state == .ended)

        harness.coordinator.completeOnboarding()
        #expect(harness.session.state == .active)

        let webScreen = screen(
            [webBlock("Welcome to the live translation"), webBlock("Scroll to translate more")],
            fingerprint: "web",
            at: 1000
        )
        await harness.pipeline.process(webScreen)
        guard case .ready(let captions) = harness.sink.states.last else {
            Issue.record("expected floating captions, got \(String(describing: harness.sink.states.last))")
            return
        }
        #expect(captions.count == 2)
        #expect(captions[0].translatedText == "[english] Welcome to the live translation")

        let webtoonScreen = screen(
            [webtoonBlock("こんにちは", y: 0.1), webtoonBlock("またね", y: 0.3)],
            fingerprint: "webtoon",
            at: 1200
        )
        await harness.pipeline.process(webtoonScreen)
        guard case .inPlaceReady(let layout) = harness.sink.states.last else {
            Issue.record("expected in-place layout, got \(String(describing: harness.sink.states.last))")
            return
        }
        #expect(layout.placements.count == 2)
        #expect(layout.placements[0].sourceText == "こんにちは")
        #expect(harness.papago.calls.contains("こんにちは"))

        harness.coordinator.toggle()
        #expect(harness.session.state == .ended)
    }

    @Test("v1 시나리오에서 캐스케이드 폴백 이벤트가 전달된다")
    func journeyReportsCascadeFallback() async throws {
        let harness = makeHarness()
        harness.coordinator.toggle()
        harness.coordinator.completeOnboarding()

        harness.papago.error = PapagoV1StubError.down
        await harness.pipeline.process(
            screen([webtoonBlock("こんにちは", y: 0.1)], fingerprint: "webtoon")
        )
        #expect(harness.sink.cascadeEvents.contains(.fellBackToOnDevice(reason: .papagoError)))
        guard case .inPlaceReady(let layout) = harness.sink.states.last else {
            Issue.record("expected in-place layout after fallback, got \(String(describing: harness.sink.states.last))")
            return
        }
        #expect(layout.placements[0].translatedText == "온디바이스 こんにちは")
    }

    @Test("세션이 끝나면 대기 화면의 불필요한 캡처 활동이 멈춘다")
    func captureActivityStopsWhenSessionEnds() {
        let harness = makeHarness()
        harness.coordinator.toggle()
        harness.coordinator.completeOnboarding()
        let activitySink = V1ActivitySink()
        harness.coordinator.onCaptureActivityChange = { activitySink.activities.append($0) }

        let t0 = Date(timeIntervalSince1970: 2000)
        _ = harness.coordinator.observeScreen(fingerprint: "A", at: t0)
        harness.coordinator.toggle()
        _ = harness.coordinator.observeScreen(fingerprint: "A", at: t0.addingTimeInterval(1))
        #expect(activitySink.activities == [.active, .standby])
    }
}

private final class V1ActivitySink: @unchecked Sendable {
    var activities: [CaptureActivity] = []
}

private enum PapagoV1StubError: Error {
    case down
}
