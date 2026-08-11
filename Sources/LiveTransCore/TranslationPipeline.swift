public enum CaptionState: Equatable, Sendable {
    case idle
    case preparing
    case ready([TranslatedTextBlock])
    case inPlaceReady(InPlaceLayout)
    case needsSourceSelection
    case failed
}

public struct TranslatedTextBlock: Equatable, Sendable {
    public let sourceText: String
    public let rect: NormalizedRect
    public let translatedText: String

    public init(sourceText: String, rect: NormalizedRect, translatedText: String) {
        self.sourceText = sourceText
        self.rect = rect
        self.translatedText = translatedText
    }
}

public final class TranslationPipeline<Payload: Sendable>: @unchecked Sendable {
    public typealias OCR = @Sendable (Payload) async throws -> [ScreenTextBlock]
    public typealias Translator = @Sendable (String, Language) async throws -> String

    private let changeDetector: ChangeDetector
    private let languageDetector: any SourceLanguageDetecting
    private let ocr: OCR
    private let translator: Translator
    private let cascadeTranslator: CascadeTranslator?
    private let inPlaceModeDecider: InPlaceModeDecider?
    private let inPlaceLayoutEngine: InPlaceLayoutEngine?

    public var filter: ScreenTextFilter
    public var manualSourceLanguage: Language?
    public var isPaused: Bool = false

    public var onCaptionStateChange: (@Sendable (CaptionState) -> Void)?
    public var onCascadeEvent: (@Sendable (CascadeEvent) -> Void)?

    public init(
        changeDetector: ChangeDetector,
        languageDetector: any SourceLanguageDetecting,
        ocr: @escaping OCR,
        translator: @escaping Translator,
        filter: ScreenTextFilter = ScreenTextFilter(),
        cascadeTranslator: CascadeTranslator? = nil,
        inPlaceModeDecider: InPlaceModeDecider? = nil,
        inPlaceLayoutEngine: InPlaceLayoutEngine? = nil
    ) {
        self.changeDetector = changeDetector
        self.languageDetector = languageDetector
        self.ocr = ocr
        self.translator = translator
        self.filter = filter
        self.cascadeTranslator = cascadeTranslator
        self.inPlaceModeDecider = inPlaceModeDecider
        self.inPlaceLayoutEngine = inPlaceLayoutEngine
        cascadeTranslator?.onEvent = { [weak self] event in
            self?.onCascadeEvent?(event)
        }
    }

    public func pause() {
        isPaused = true
    }

    public func resume() {
        isPaused = false
    }

    public func process(_ screen: CapturedScreen<Payload>) async {
        guard !isPaused else { return }

        let shouldProcess = changeDetector.shouldProcess(
            fingerprint: screen.fingerprint,
            at: screen.capturedAt
        )
        guard shouldProcess else { return }

        onCaptionStateChange?(.preparing)
        do {
            let recognized = try await ocr(screen.payload)
            let blocks = filter.applying(to: recognized)
            guard !blocks.isEmpty else {
                onCaptionStateChange?(.ready([]))
                return
            }

            let language = resolveSourceLanguage(blocks: blocks)
            guard language != .undetermined else {
                onCaptionStateChange?(.needsSourceSelection)
                return
            }

            var translated: [TranslatedTextBlock] = []
            for block in blocks {
                let result: String
                if block.kind == .embedded, let cascadeTranslator {
                    result = try await cascadeTranslator.translate(block.text, from: language)
                } else {
                    result = try await translator(block.text, language)
                }
                translated.append(
                    TranslatedTextBlock(
                        sourceText: block.text,
                        rect: block.rect,
                        translatedText: result
                    )
                )
            }

            if inPlaceModeDecider?.decidesInPlace(blocks: blocks) == .inPlace,
               let inPlaceLayoutEngine {
                let layout = inPlaceLayoutEngine.layout(translated: translated, sourceLanguage: language)
                onCaptionStateChange?(.inPlaceReady(layout))
            } else {
                onCaptionStateChange?(.ready(translated))
            }
        } catch {
            onCaptionStateChange?(.failed)
        }
    }

    private func resolveSourceLanguage(blocks: [ScreenTextBlock]) -> Language {
        if let manualSourceLanguage {
            return manualSourceLanguage
        }
        return languageDetector.detectSourceLanguage(in: blocks)
    }
}