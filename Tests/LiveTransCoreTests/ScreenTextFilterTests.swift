import Testing
import LiveTransCore

@Suite
struct ScreenTextFilterTests {
    private let filter = ScreenTextFilter()

    private func block(_ text: String) -> ScreenTextBlock {
        ScreenTextBlock(text: text, rect: .init(x: 0, y: 0, width: 1, height: 1))
    }

    @Test("1~2글자 단독 텍스트는 제거된다")
    func filtersShortStandaloneText() {
        let blocks = [block("I"), block("OK"), block("Read more")]
        let kept = filter.applying(to: blocks)
        #expect(kept.map(\.text) == ["Read more"])
    }

    @Test("숫자·기호만 있는 텍스트는 제거된다")
    func filtersNumberAndSymbolOnly() {
        let blocks = [block("12345"), block("!!!"), block("Price 99")]
        let kept = filter.applying(to: blocks)
        #expect(kept.map(\.text) == ["Price 99"])
    }

    @Test("이미 한국어인 텍스트는 제거된다")
    func filtersKoreanText() {
        let blocks = [block("안녕하세요"), block("Hello")]
        let kept = filter.applying(to: blocks)
        #expect(kept.map(\.text) == ["Hello"])
    }

    @Test("동일 문자열이 반복되면 중복은 제거된다")
    func collapsesDuplicateBlocks() {
        let blocks = [block("Agree"), block("Agree"), block("Agree"), block("Skip")]
        let kept = filter.applying(to: blocks)
        #expect(kept.map(\.text) == ["Agree", "Skip"])
    }

    @Test("대소문자만 다른 반복도 중복으로 처리한다")
    func collapseIsCaseInsensitive() {
        let blocks = [block("Start"), block("start")]
        let kept = filter.applying(to: blocks)
        #expect(kept.count == 1)
    }

    @Test("빈 텍스트는 제거된다")
    func filtersEmptyText() {
        let blocks = [block("   "), block("Hello")]
        let kept = filter.applying(to: blocks)
        #expect(kept.map(\.text) == ["Hello"])
    }

    @Test("규칙을 끄면 해당 필터링을 하지 않는다")
    func rulesCanBeDisabled() {
        var filter = ScreenTextFilter()
        filter.filtersOutKorean = false
        filter.minimumLetterCount = 1
        let blocks = [block("안녕"), block("I")]
        let kept = filter.applying(to: blocks)
        #expect(kept.count == 2)
    }
}