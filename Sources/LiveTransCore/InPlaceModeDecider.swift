public enum DisplayMode: Equatable, Sendable {
    case floatingCaption
    case inPlace
}

public struct InPlaceModeDecider: Sendable {
    public var embeddedBlockThreshold: Int
    public var embeddedShareThreshold: Double

    public init(
        embeddedBlockThreshold: Int = 1,
        embeddedShareThreshold: Double = 0.5
    ) {
        self.embeddedBlockThreshold = embeddedBlockThreshold
        self.embeddedShareThreshold = embeddedShareThreshold
    }

    public func decidesInPlace(blocks: [ScreenTextBlock]) -> DisplayMode {
        guard !blocks.isEmpty else { return .floatingCaption }

        let embeddedCount = blocks.filter { $0.kind == .embedded }.count
        let total = blocks.count
        let share = Double(embeddedCount) / Double(total)

        if embeddedCount >= embeddedBlockThreshold, share >= embeddedShareThreshold {
            return .inPlace
        }
        return .floatingCaption
    }
}