public struct ScreenTextFilter: Sendable, Equatable {
    public var minimumLetterCount: Int
    public var filtersOutNumberAndSymbolOnly: Bool
    public var filtersOutKorean: Bool
    public var collapsesDuplicateBlocks: Bool

    public init(
        minimumLetterCount: Int = 3,
        filtersOutNumberAndSymbolOnly: Bool = true,
        filtersOutKorean: Bool = true,
        collapsesDuplicateBlocks: Bool = true
    ) {
        self.minimumLetterCount = minimumLetterCount
        self.filtersOutNumberAndSymbolOnly = filtersOutNumberAndSymbolOnly
        self.filtersOutKorean = filtersOutKorean
        self.collapsesDuplicateBlocks = collapsesDuplicateBlocks
    }

    public func applying(to blocks: [ScreenTextBlock]) -> [ScreenTextBlock] {
        let languageDetector = HeuristicSourceLanguageDetector()
        var seen: Set<String> = []
        return blocks.filter { block in
            let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }

            let letterCount = trimmed.filter(\.isLetter).count
            guard letterCount >= minimumLetterCount else { return false }

            if filtersOutNumberAndSymbolOnly, letterCount == 0 {
                return false
            }

            if filtersOutKorean,
               languageDetector.detectSourceLanguage(of: trimmed) == .korean {
                return false
            }

            if collapsesDuplicateBlocks {
                let key = trimmed.lowercased()
                guard !seen.contains(key) else { return false }
                seen.insert(key)
            }

            return true
        }
    }
}