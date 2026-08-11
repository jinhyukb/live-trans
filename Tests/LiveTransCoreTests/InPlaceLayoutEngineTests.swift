import Testing
import LiveTransCore

@Suite
struct InPlaceLayoutEngineTests {
    private let engine = InPlaceLayoutEngine()

    private func block(_ text: String, rect: NormalizedRect) -> TranslatedTextBlock {
        TranslatedTextBlock(
            sourceText: text,
            rect: rect,
            translatedText: "번역:\(text)"
        )
    }

    @Test("짧은 번역문은 원문 위치에 한 줄로 배치된다")
    func shortTextKeepsSourceRect() {
        let rect = NormalizedRect(x: 0.1, y: 0.1, width: 0.4, height: 0.1)
        let layout = engine.layout(translated: [block("Hi", rect: rect)])
        #expect(layout.placements.count == 1)
        #expect(layout.placements[0].placementRect == rect)
        #expect(layout.placements[0].lineCount == 1)
        #expect(layout.placements[0].fontSizeScale > 0.8)
    }

    @Test("긴 번역문은 짧은 번역문보다 폰트 스케일이 작다")
    func longTextScalesMoreThanShortText() {
        let rect = NormalizedRect(x: 0.1, y: 0.1, width: 0.4, height: 0.1)
        let longLayout = engine.layout(translated: [block(String(repeating: "아", count: 80), rect: rect)])
        let shortLayout = engine.layout(translated: [block("Hi", rect: rect)])
        #expect(longLayout.placements[0].fontSizeScale < shortLayout.placements[0].fontSizeScale)
    }

    @Test("서로 겹치는 블록은 아래로 밀려난다")
    func overlappingBlocksAreSeparated() {
        let top = block("Top", rect: .init(x: 0.1, y: 0.1, width: 0.4, height: 0.1))
        let bottom = block("Bottom", rect: .init(x: 0.1, y: 0.15, width: 0.4, height: 0.1))
        let layout = engine.layout(translated: [bottom, top])
        #expect(layout.placements.count == 2)
        let sorted = layout.placements.sorted { $0.placementRect.y < $1.placementRect.y }
        #expect(
            sorted[0].placementRect.y + sorted[0].placementRect.height
                <= sorted[1].placementRect.y
                || sorted[0].placementRect.y > sorted[1].placementRect.y
        )
    }

    @Test("번역문이 원문보다 짧아도 제자리 위치를 유지한다")
    func placementRectCenteredWithinSource() {
        let rect = NormalizedRect(x: 0.2, y: 0.2, width: 0.6, height: 0.2)
        let layout = engine.layout(translated: [block("A", rect: rect)])
        #expect(layout.placements[0].placementRect == rect)
    }

    @Test("소스 언어가 레이아웃에 함께 전달된다")
    func carriesSourceLanguage() {
        let rect = NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5)
        let layout = engine.layout(translated: [block("Hello", rect: rect)], sourceLanguage: .japanese)
        #expect(layout.sourceLanguage == .japanese)
    }

    @Test("너비가 없는 블록은 최소 폰트 스케일로 배치된다")
    func zeroWidthBlockUsesMinFontScale() {
        let rect = NormalizedRect(x: 0, y: 0, width: 0, height: 0)
        let layout = engine.layout(translated: [block("Hello", rect: rect)])
        #expect(layout.placements[0].fontSizeScale <= 1.0)
        #expect(layout.placements[0].lineCount >= 1)
    }
}