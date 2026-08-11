import Foundation

public struct TranslationQuota: Equatable, Sendable {
    public let dailyLimit: Int
    public let usedCharacters: Int
    public let dayIdentifier: String

    public var remainingCharacters: Int {
        max(0, dailyLimit - usedCharacters)
    }

    public var isExhausted: Bool {
        usedCharacters >= dailyLimit
    }

    public init(dailyLimit: Int, usedCharacters: Int, dayIdentifier: String) {
        self.dailyLimit = dailyLimit
        self.usedCharacters = usedCharacters
        self.dayIdentifier = dayIdentifier
    }
}

public protocol TranslationQuotaStoring: Sendable {
    func load() -> TranslationQuota?
    func save(_ quota: TranslationQuota)
}