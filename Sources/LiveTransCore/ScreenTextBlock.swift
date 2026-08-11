public enum ScreenTextKind: Equatable, Sendable {
    case onScreen
    case embedded
}

public struct ScreenTextBlock: Equatable, Sendable {
    public let text: String
    public let rect: NormalizedRect
    public let languageHint: Language?
    public let kind: ScreenTextKind

    public init(
        text: String,
        rect: NormalizedRect,
        languageHint: Language? = nil,
        kind: ScreenTextKind = .onScreen
    ) {
        self.text = text
        self.rect = rect
        self.languageHint = languageHint
        self.kind = kind
    }
}