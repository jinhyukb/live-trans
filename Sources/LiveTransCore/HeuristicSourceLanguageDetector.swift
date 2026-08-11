public protocol SourceLanguageDetecting: Sendable {
    func detectSourceLanguage(in blocks: [ScreenTextBlock]) -> Language
}

public struct HeuristicSourceLanguageDetector: SourceLanguageDetecting {
    public init() {}

    public func detectSourceLanguage(in blocks: [ScreenTextBlock]) -> Language {
        let hints = blocks.compactMap(\.languageHint)
        if let dominant = dominantLanguage(of: hints) {
            return dominant
        }
        let text = blocks.map(\.text).joined()
        return detect(fromCharacters: text)
    }

    public func detectSourceLanguage(of text: String) -> Language {
        detect(fromCharacters: text)
    }

    private func dominantLanguage(of languages: [Language]) -> Language? {
        var counts: [Language: Int] = [:]
        for language in languages where language != .undetermined {
            counts[language, default: 0] += 1
        }
        return counts.max { $0.value < $1.value }?.key
    }

    private func detect(fromCharacters text: String) -> Language {
        var latinCount = 0
        var hangulCount = 0
        var kanaCount = 0
        var hanCount = 0
        var letterCount = 0

        for scalar in text.unicodeScalars {
            if isLatin(scalar) {
                latinCount += 1
                letterCount += 1
            } else if isHangul(scalar) {
                hangulCount += 1
                letterCount += 1
            } else if isHiraganaOrKatakana(scalar) {
                kanaCount += 1
                letterCount += 1
            } else if isHan(scalar) {
                hanCount += 1
                letterCount += 1
            }
        }

        guard letterCount > 0 else { return .undetermined }

        if hangulCount > 0, hangulCount * 2 >= letterCount {
            return .korean
        }
        if kanaCount > 0 {
            return .japanese
        }
        if hanCount > 0, hanCount * 2 >= letterCount {
            return .japanese
        }
        if latinCount > 0 {
            return .english
        }
        return .undetermined
    }

    private func isLatin(_ scalar: Unicode.Scalar) -> Bool {
        (scalar.value >= 0x0041 && scalar.value <= 0x005A)
            || (scalar.value >= 0x0061 && scalar.value <= 0x007A)
            || (scalar.value >= 0x00C0 && scalar.value <= 0x024F)
    }

    private func isHangul(_ scalar: Unicode.Scalar) -> Bool {
        (scalar.value >= 0xAC00 && scalar.value <= 0xD7A3)
            || (scalar.value >= 0x1100 && scalar.value <= 0x11FF)
            || (scalar.value >= 0x3130 && scalar.value <= 0x318F)
    }

    private func isHiraganaOrKatakana(_ scalar: Unicode.Scalar) -> Bool {
        (scalar.value >= 0x3040 && scalar.value <= 0x30FF)
            || (scalar.value >= 0x31F0 && scalar.value <= 0x31FF)
    }

    private func isHan(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 0x4E00 && scalar.value <= 0x9FFF
    }
}