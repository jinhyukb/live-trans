import Testing
import LiveTransCore

@Suite
struct InPlaceModeDeciderTests {
    private let decider = InPlaceModeDecider()

    private func block(_ kind: ScreenTextKind) -> ScreenTextBlock {
        ScreenTextBlock(
            text: "Text",
            rect: .init(x: 0, y: 0, width: 1, height: 1),
            kind: kind
        )
    }

    @Test("이미지 속 텍스트가 지배적이면 제자리 번역으로 전환한다")
    func switchesToInPlaceWhenEmbeddedDominates() {
        let blocks = [block(.embedded), block(.embedded), block(.onScreen)]
        #expect(decider.decidesInPlace(blocks: blocks) == .inPlace)
    }

    @Test("화면 속 텍스트가 지배적이면 플로팅 캡션을 유지한다")
    func keepsFloatingCaptionWhenOnScreenDominates() {
        let blocks = [block(.onScreen), block(.onScreen), block(.embedded)]
        #expect(decider.decidesInPlace(blocks: blocks) == .floatingCaption)
    }

    @Test("블록이 없으면 플로팅 캡션을 유지한다")
    func emptyBlocksStayFloating() {
        #expect(decider.decidesInPlace(blocks: []) == .floatingCaption)
    }

    @Test("이미지 속 텍스트가 전부이면 제자리 번역으로 전환한다")
    func allEmbeddedSwitchesToInPlace() {
        let blocks = [block(.embedded)]
        #expect(decider.decidesInPlace(blocks: blocks) == .inPlace)
    }

    @Test("임계값 설정이 전환 판정에 반영된다")
    func thresholdAffectsDecision() {
        var decider = InPlaceModeDecider()
        decider.embeddedBlockThreshold = 3
        let blocks = [block(.embedded), block(.embedded)]
        #expect(decider.decidesInPlace(blocks: blocks) == .floatingCaption)
    }
}