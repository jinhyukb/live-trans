import Foundation

public struct InPlaceTextPlacement: Equatable, Sendable {
    public let sourceText: String
    public let translatedText: String
    public let sourceRect: NormalizedRect
    public let placementRect: NormalizedRect
    public let fontSizeScale: Double
    public let lineCount: Int
}

public struct InPlaceLayout: Equatable, Sendable {
    public let placements: [InPlaceTextPlacement]
    public let sourceLanguage: Language?

    public init(placements: [InPlaceTextPlacement], sourceLanguage: Language? = nil) {
        self.placements = placements
        self.sourceLanguage = sourceLanguage
    }
}

public struct InPlaceLayoutMetrics: Equatable, Sendable {
    public var characterAspectRatio: Double
    public var lineHeightRatio: Double
    public var maxTextToBlockWidthRatio: Double
    public var minFontScale: Double

    public init(
        characterAspectRatio: Double = 0.5,
        lineHeightRatio: Double = 1.2,
        maxTextToBlockWidthRatio: Double = 0.9,
        minFontScale: Double = 0.5
    ) {
        self.characterAspectRatio = characterAspectRatio
        self.lineHeightRatio = lineHeightRatio
        self.maxTextToBlockWidthRatio = maxTextToBlockWidthRatio
        self.minFontScale = minFontScale
    }
}

public struct InPlaceLayoutEngine: Sendable {
    private let metrics: InPlaceLayoutMetrics

    public init(metrics: InPlaceLayoutMetrics = InPlaceLayoutMetrics()) {
        self.metrics = metrics
    }

    public func layout(
        translated: [TranslatedTextBlock],
        sourceLanguage: Language? = nil
    ) -> InPlaceLayout {
        var placements = translated.map { fit($0) }
        placements = resolveOverlaps(placements)
        return InPlaceLayout(placements: placements, sourceLanguage: sourceLanguage)
    }

    private func fit(_ block: TranslatedTextBlock) -> InPlaceTextPlacement {
        let rect = block.rect
        guard rect.width > 0, rect.height > 0 else {
            return InPlaceTextPlacement(
                sourceText: block.sourceText,
                translatedText: block.translatedText,
                sourceRect: rect,
                placementRect: rect,
                fontSizeScale: metrics.minFontScale,
                lineCount: 1
            )
        }

        let availableWidth = rect.width * metrics.maxTextToBlockWidthRatio
        let textLength = Double(max(block.translatedText.count, 1))
        var fontSize = rect.height
        var lineCount = max(1, Int(ceil(textLength * metrics.characterAspectRatio * fontSize / availableWidth)))
        var requiredHeight = Double(lineCount) * fontSize * metrics.lineHeightRatio

        if requiredHeight > rect.height {
            fontSize *= rect.height / requiredHeight
            lineCount = max(1, Int(ceil(textLength * metrics.characterAspectRatio * fontSize / availableWidth)))
            requiredHeight = Double(lineCount) * fontSize * metrics.lineHeightRatio
            if requiredHeight > rect.height {
                fontSize *= rect.height / requiredHeight
            }
        }

        let minFont = rect.height * metrics.minFontScale
        fontSize = max(minFont, fontSize)
        let fontSizeScale = min(1.0, fontSize / rect.height)

        return InPlaceTextPlacement(
            sourceText: block.sourceText,
            translatedText: block.translatedText,
            sourceRect: rect,
            placementRect: rect,
            fontSizeScale: fontSizeScale,
            lineCount: lineCount
        )
    }

    private func resolveOverlaps(_ placements: [InPlaceTextPlacement]) -> [InPlaceTextPlacement] {
        let sorted = placements.sorted { $0.sourceRect.y < $1.sourceRect.y }
        var resolved: [InPlaceTextPlacement] = []

        for placement in sorted {
            var rect = placement.placementRect
            for previous in resolved {
                if intersects(rect, previous.placementRect) {
                    let delta = previous.placementRect.maxY - rect.minY
                    if delta > 0 {
                        rect = NormalizedRect(
                            x: rect.x,
                            y: min(rect.y + delta, 1 - rect.height),
                            width: rect.width,
                            height: rect.height
                        )
                    }
                }
            }
            resolved.append(
                InPlaceTextPlacement(
                    sourceText: placement.sourceText,
                    translatedText: placement.translatedText,
                    sourceRect: placement.sourceRect,
                    placementRect: rect,
                    fontSizeScale: placement.fontSizeScale,
                    lineCount: placement.lineCount
                )
            )
        }
        return resolved
    }

    private func intersects(_ a: NormalizedRect, _ b: NormalizedRect) -> Bool {
        a.minX < b.maxX && a.maxX > b.minX && a.minY < b.maxY && a.maxY > b.minY
    }
}

private extension NormalizedRect {
    var minX: Double { x }
    var minY: Double { y }
    var maxX: Double { x + width }
    var maxY: Double { y + height }
}