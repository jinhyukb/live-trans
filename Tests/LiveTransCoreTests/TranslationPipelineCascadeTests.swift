import Foundation
import Testing
import LiveTransCore

@Suite
struct TranslationPipelineCascadeTests {
    private struct Payload: Sendable {
        let blocks: [ScreenTextBlock]
    }

    private final class StateSink: @unchecked Sendable {
        var states: [CaptionState] = []
        var cascadeEvents: [CascadeEvent] = []
    }

    private func makeEmbeddedBlock(_ text: String, y: Double = 0.1) -> ScreenTextBlock {
        ScreenTextBlock(
            text: text,
            rect: NormalizedRect(x: 0.1, y: y, width: 0.4, height: 0.1),
            kind: .embedded
        )
    }

    private func makePipeline(
        cascade: CascadeTranslator?,
        inPlaceDecider: InPlaceModeDecider? = nil
    ) -> (pipeline: TranslationPipeline<Payload>, sink: StateSink) {
        let sink = StateSink()
        let pipeline = TranslationPipeline<Payload>(
            changeDetector: ChangeDetector(),
            languageDetector: HeuristicSourceLanguageDetector(),
            ocr: { $0.blocks },
            translator: { text, language in
                "[on-device] \(text)"
            },
            cascadeTranslator: cascade,
            inPlaceModeDecider: inPlaceDecider,
            inPlaceLayoutEngine: inPlaceDecider == nil ? nil : InPlaceLayoutEngine()
        )
        pipeline.onCaptionStateChange = { sink.states.append($0) }
        pipeline.onCascadeEvent = { sink.cascadeEvents.append($0) }
        return (pipeline, sink)
    }

    private func screen(_ blocks: [ScreenTextBlock]) -> CapturedScreen<Payload> {
        CapturedScreen(
            fingerprint: "A",
            capturedAt: Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: 2026, month: 8, day: 11, hour: 12))!,
            payload: Payload(blocks: blocks)
        )
    }

    @Test("이미지 속 텍스트는 캐스케이드(Papago)를 통한다")
    func embeddedBlocksRouteThroughCascade() async throws {
        let papago = StubPapagoTranslator()
        papago.result = "Papago 번역"
        let cascade = CascadeTranslator(
            onDevice: { text, _ in "온디바이스 \(text)" },
            papago: papago,
            quotaTracker: TranslationQuotaTracker(
                dailyLimit: 10_000,
                storage: InMemoryTranslationQuotaStore(),
                calendar: Calendar(identifier: .gregorian)
            )
        )
        let (pipeline, sink) = makePipeline(cascade: cascade)
        await pipeline.process(screen([makeEmbeddedBlock("こんにちは")]))
        guard case .ready(let translated) = sink.states.last else {
            Issue.record("expected ready, got \(String(describing: sink.states.last))")
            return
        }
        #expect(translated[0].translatedText == "Papago 번역")
        #expect(papago.calls == ["こんにちは"])
    }

    @Test("제자리 모드로 판정되면 inPlaceReady 레이아웃을 낸다")
    func inPlaceModeProducesLayout() async throws {
        let cascade = CascadeTranslator(
            onDevice: { text, _ in "온디바이스 \(text)" },
            papago: StubPapagoTranslator(result: "Papago 번역"),
            quotaTracker: TranslationQuotaTracker(
                dailyLimit: 10_000,
                storage: InMemoryTranslationQuotaStore(),
                calendar: Calendar(identifier: .gregorian)
            )
        )
        let decider = InPlaceModeDecider(embeddedBlockThreshold: 1, embeddedShareThreshold: 0.5)
        let (pipeline, sink) = makePipeline(cascade: cascade, inPlaceDecider: decider)
        await pipeline.process(screen([makeEmbeddedBlock("こんにちは")]))
        guard case .inPlaceReady(let layout) = sink.states.last else {
            Issue.record("expected inPlaceReady, got \(String(describing: sink.states.last))")
            return
        }
        #expect(layout.placements.count == 1)
        #expect(layout.placements[0].sourceText == "こんにちは")
        #expect(layout.placements[0].placementRect == layout.placements[0].sourceRect)
    }

    @Test("캐스케이드 폴백 이벤트가 파이프라인을 통해 전달된다")
    func cascadeFallbackEventForwardsThroughPipeline() async throws {
        let cascade = CascadeTranslator(
            onDevice: { text, _ in "온디바이스 \(text)" },
            papago: StubPapagoTranslator(error: PapagoStubError.down),
            quotaTracker: TranslationQuotaTracker(
                dailyLimit: 10_000,
                storage: InMemoryTranslationQuotaStore(),
                calendar: Calendar(identifier: .gregorian)
            )
        )
        let (pipeline, sink) = makePipeline(cascade: cascade)
        await pipeline.process(screen([makeEmbeddedBlock("こんにちは")]))
        #expect(sink.cascadeEvents.contains(.fellBackToOnDevice(reason: .papagoError)))
        guard case .ready(let translated) = sink.states.last else {
            Issue.record("expected ready, got \(String(describing: sink.states.last))")
            return
        }
        #expect(translated[0].translatedText == "온디바이스 こんにちは")
    }
}

private enum PapagoStubError: Error {
    case down
}