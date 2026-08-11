import Foundation
import Testing
import LiveTransCore

final class InMemoryTranslationQuotaStore: TranslationQuotaStoring, @unchecked Sendable {
    private var stored: TranslationQuota?
    private(set) var saveCount = 0

    init(initial: TranslationQuota? = nil) {
        self.stored = initial
    }

    func load() -> TranslationQuota? {
        stored
    }

    func save(_ quota: TranslationQuota) {
        stored = quota
        saveCount += 1
    }
}

@Suite
struct TranslationQuotaTrackerTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test("쿼터가 없으면 0 사용으로 시작한다")
    func startsFreshWhenNothingStored() {
        let store = InMemoryTranslationQuotaStore()
        let tracker = TranslationQuotaTracker(dailyLimit: 10_000, storage: store, calendar: calendar)
        let quota = tracker.currentQuota(asOf: day(2026, 8, 11))
        #expect(quota.usedCharacters == 0)
        #expect(quota.remainingCharacters == 10_000)
        #expect(!quota.isExhausted)
    }

    @Test("소비하면 사용량이 누적되고 저장된다")
    func consumeAccumulatesAndPersists() {
        let store = InMemoryTranslationQuotaStore()
        let tracker = TranslationQuotaTracker(dailyLimit: 10_000, storage: store, calendar: calendar)
        let date = day(2026, 8, 11)
        tracker.consume(1_200, asOf: date)
        tracker.consume(800, asOf: date)
        #expect(store.load()?.usedCharacters == 2_000)
        #expect(store.load()?.remainingCharacters == 8_000)
    }

    @Test("하루 쿼터를 넘지 못하게 클램프한다")
    func consumeClampsAtDailyLimit() {
        let store = InMemoryTranslationQuotaStore()
        let tracker = TranslationQuotaTracker(dailyLimit: 10_000, storage: store, calendar: calendar)
        let date = day(2026, 8, 11)
        tracker.consume(9_500, asOf: date)
        tracker.consume(9_000, asOf: date)
        #expect(store.load()?.usedCharacters == 10_000)
        #expect(store.load()?.isExhausted == true)
        #expect(tracker.canConsume(1, asOf: date) == false)
    }

    @Test("날짜가 바뀌면 쿼터가 리셋된다")
    func quotaResetsOnNewDay() {
        let store = InMemoryTranslationQuotaStore()
        let tracker = TranslationQuotaTracker(dailyLimit: 10_000, storage: store, calendar: calendar)
        tracker.consume(9_500, asOf: day(2026, 8, 11))
        let nextDay = day(2026, 8, 12)
        let quota = tracker.currentQuota(asOf: nextDay)
        #expect(quota.usedCharacters == 0)
        #expect(quota.dayIdentifier == "2026-08-12")
        #expect(tracker.canConsume(9_500, asOf: nextDay))
    }

    @Test("같은 날이면 저장된 쿼터를 그대로 쓴다")
    func sameDayKeepsStoredQuota() {
        let date = day(2026, 8, 11)
        let stored = TranslationQuota(dailyLimit: 10_000, usedCharacters: 4_200, dayIdentifier: "2026-08-11")
        let store = InMemoryTranslationQuotaStore(initial: stored)
        let tracker = TranslationQuotaTracker(dailyLimit: 10_000, storage: store, calendar: calendar)
        #expect(tracker.currentQuota(asOf: date).usedCharacters == 4_200)
    }
}