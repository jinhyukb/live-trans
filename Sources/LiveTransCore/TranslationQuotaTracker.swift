import Foundation

public final class TranslationQuotaTracker: @unchecked Sendable {
    public static let defaultDailyLimit = 10_000

    private let dailyLimit: Int
    private let storage: any TranslationQuotaStoring
    private let calendar: Calendar

    public init(
        dailyLimit: Int = TranslationQuotaTracker.defaultDailyLimit,
        storage: any TranslationQuotaStoring,
        calendar: Calendar = .current
    ) {
        self.dailyLimit = dailyLimit
        self.storage = storage
        self.calendar = calendar
    }

    public func currentQuota(asOf date: Date) -> TranslationQuota {
        let dayIdentifier = Self.dayIdentifier(for: date, calendar: calendar)
        guard let stored = storage.load(), stored.dayIdentifier == dayIdentifier else {
            return TranslationQuota(dailyLimit: dailyLimit, usedCharacters: 0, dayIdentifier: dayIdentifier)
        }
        return stored
    }

    public func canConsume(_ characterCount: Int, asOf date: Date) -> Bool {
        currentQuota(asOf: date).remainingCharacters >= characterCount
    }

    @discardableResult
    public func consume(_ characterCount: Int, asOf date: Date) -> TranslationQuota {
        let dayIdentifier = Self.dayIdentifier(for: date, calendar: calendar)
        let stored = storage.load()
        let used = (stored?.dayIdentifier == dayIdentifier ? stored?.usedCharacters : 0) ?? 0
        let updated = TranslationQuota(
            dailyLimit: dailyLimit,
            usedCharacters: min(dailyLimit, used + characterCount),
            dayIdentifier: dayIdentifier
        )
        storage.save(updated)
        return updated
    }

    public static func dayIdentifier(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}