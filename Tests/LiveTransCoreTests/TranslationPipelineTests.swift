import Foundation
import Testing
import LiveTransCore

@Suite
struct TranslationPipelineTests {
    private struct Payload: Sendable {
        let blocks: [ScreenTextBlock]
    }

    private final class StateSink: @unchecked Sendable {
        var states: [CaptionState] = []
    }

    private func makePipeline(
        changeDetector: ChangeDetector = ChangeDetector(),
        filter: ScreenTextFilter = ScreenTextFilter(),
        ocrError: (any Error)? = nil,
        translateError: (any Error)? = nil
    ) -> (pipeline: TranslationPipeline<Payload>, sink: StateSink) {
        let sink = StateSink()
        let pipeline = TranslationPipeline<Payload>(
            changeDetector: changeDetector,
            languageDetector: HeuristicSourceLanguageDetector(),
            ocr: { payload in
                if let ocrError { throw ocrError }
                return payload.blocks
            },
            translator: { text, language in
                if let translateError { throw translateError }
                return "[\(language)] \(text)"
            },
            filter: filter
        )
        pipeline.onCaptionStateChange = { sink.states.append($0) }
        return (pipeline, sink)
    }

    private func screen(_ blocks: [ScreenTextBlock], fingerprint: String = "A") -> CapturedScreen<Payload> {
        CapturedScreen(
            fingerprint: fingerprint,
            capturedAt: Date(timeIntervalSince1970: 1000),
            payload: Payload(blocks: blocks)
        )
    }

    @Test("변화 없으면 캡션 상태를 다시 내보내지 않는다")
    func noChangeEmitsNothing() async {
        let (pipeline, sink) = makePipeline()
        await pipeline.process(screen([], fingerprint: "A"))
        await pipeline.process(screen([], fingerprint: "A"))
        #expect(sink.states.count == 2)
    }

    @Test("화면 속 텍스트가 번역되어 ready 상태가 된다")
    func translatesBlocksToReady() async {
        let (pipeline, sink) = makePipeline()
        let blocks = [
            ScreenTextBlock(text: "Hello world", rect: .init(x: 0, y: 0, width: 1, height: 0.5)),
        ]
        await pipeline.process(screen(blocks))
        #expect(
            sink.states == [
                .preparing,
                .ready([
                    TranslatedTextBlock(
                        sourceText: "Hello world",
                        rect: .init(x: 0, y: 0, width: 1, height: 0.5),
                        translatedText: "[english] Hello world"
                    )
                ]),
            ]
        )
    }

    @Test("OCR이 실패하면 failed 상태가 된다")
    func ocrFailureEmitsFailed() async {
        let (pipeline, sink) = makePipeline(ocrError: TestError.failure)
        await pipeline.process(screen([]))
        #expect(sink.states == [.preparing, .failed])
    }

    @Test("번역이 실패해도 파이프라인은 멈추지 않고 failed를 알린다")
    func translateFailureEmitsFailed() async {
        let (pipeline, sink) = makePipeline(translateError: TestError.failure)
        let blocks = [
            ScreenTextBlock(text: "Hello", rect: .init(x: 0, y: 0, width: 1, height: 0.5)),
        ]
        await pipeline.process(screen(blocks))
        #expect(sink.states == [.preparing, .failed])
    }

    @Test("OCR 필터가 노이즈 블록을 제거한다")
    func filterRemovesNoiseBlocks() async {
        let (pipeline, sink) = makePipeline()
        let blocks = [
            ScreenTextBlock(text: "I", rect: .init(x: 0, y: 0, width: 0.3, height: 0.5)),
            ScreenTextBlock(text: "12345", rect: .init(x: 0.3, y: 0, width: 0.3, height: 0.5)),
            ScreenTextBlock(text: "Hello", rect: .init(x: 0.6, y: 0, width: 0.3, height: 0.5)),
        ]
        await pipeline.process(screen(blocks))
        guard case .ready(let translated) = sink.states.last else {
            Issue.record("expected ready, got \(String(describing: sink.states.last))")
            return
        }
        #expect(translated.map(\.sourceText) == ["Hello"])
    }

    @Test("일시정지 중에는 처리하지 않는다")
    func pausedPipelineSkipsProcessing() async {
        let (pipeline, sink) = makePipeline()
        pipeline.pause()
        await pipeline.process(screen([
            ScreenTextBlock(text: "Hello", rect: .init(x: 0, y: 0, width: 1, height: 0.5)),
        ]))
        #expect(sink.states.isEmpty)
        pipeline.resume()
        await pipeline.process(screen([
            ScreenTextBlock(text: "Hello", rect: .init(x: 0, y: 0, width: 1, height: 0.5)),
        ]))
        #expect(sink.states.count == 2)
    }

    @Test("수동 소스 언어 지정이 자동 감지를 덮어쓴다")
    func manualSourceLanguageOverridesDetection() async {
        let (pipeline, sink) = makePipeline()
        pipeline.manualSourceLanguage = .japanese
        await pipeline.process(screen([
            ScreenTextBlock(text: "Hello world", rect: .init(x: 0, y: 0, width: 1, height: 0.5)),
        ]))
        guard case .ready(let translated) = sink.states.last else {
            Issue.record("expected ready, got \(String(describing: sink.states.last))")
            return
        }
        #expect(translated[0].translatedText == "[japanese] Hello world")
    }

    @Test("감지 실패 시 needsSourceSelection 상태를 알린다")
    func undeterminedLanguageEmitsNeedsSelection() async {
        let (pipeline, sink) = makePipeline()
        await pipeline.process(screen([
            ScreenTextBlock(text: "αβγδε", rect: .init(x: 0, y: 0, width: 1, height: 0.5)),
        ]))
        #expect(sink.states == [.preparing, .needsSourceSelection])
    }
}

private enum TestError: Error {
    case failure
}