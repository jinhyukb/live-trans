import Testing
import LiveTransCore

@Suite
struct HeuristicSourceLanguageDetectorTests {
    private let detector = HeuristicSourceLanguageDetector()

    @Test("영문 텍스트는 영어로 감지한다")
    func detectsEnglish() {
        #expect(detector.detectSourceLanguage(of: "The quick brown fox jumps over the lazy dog") == .english)
    }

    @Test("히라가나·가타카나가 있으면 일본어로 감지한다")
    func detectsJapaneseByKana() {
        #expect(detector.detectSourceLanguage(of: "こんにちは世界") == .japanese)
        #expect(detector.detectSourceLanguage(of: "ありがとうございます") == .japanese)
    }

    @Test("한글이 지배적이면 한국어로 감지한다")
    func detectsKorean() {
        #expect(detector.detectSourceLanguage(of: "안녕하세요 여러분") == .korean)
    }

    @Test("문자가 없거나 기호뿐이면 undetermined")
    func undeterminedForSymbols() {
        #expect(detector.detectSourceLanguage(of: "12345") == .undetermined)
        #expect(detector.detectSourceLanguage(of: "!!!") == .undetermined)
    }

    @Test("OCR 힌트가 있으면 문자 분석보다 우선한다")
    func hintWinsOverCharacters() {
        let block = ScreenTextBlock(text: "Hello", rect: NormalizedRect(x: 0, y: 0, width: 1, height: 1), languageHint: .japanese)
        #expect(detector.detectSourceLanguage(in: [block]) == .japanese)
    }

    @Test("여러 블록에서는 지배 언어를 따른다")
    func dominantHintAcrossBlocks() {
        let blocks = [
            ScreenTextBlock(text: "Hello", rect: .init(x: 0, y: 0, width: 0.5, height: 0.5), languageHint: .english),
            ScreenTextBlock(text: "Hello again", rect: .init(x: 0.5, y: 0, width: 0.5, height: 0.5), languageHint: .english),
            ScreenTextBlock(text: "こんにちは", rect: .init(x: 0, y: 0.5, width: 1, height: 0.5), languageHint: .japanese),
        ]
        #expect(detector.detectSourceLanguage(in: blocks) == .english)
    }
}