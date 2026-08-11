import Foundation
import Testing
import LiveTransCore

final class StubPapagoTranslator: PapagoTranslating, @unchecked Sendable {
    var error: (any Error)?
    var calls: [String] = []
    var result = "Papago 번역문"

    init(error: (any Error)? = nil) {
        self.error = error
    }

    init(result: String) {
        self.result = result
    }

    func translate(_ text: String, from source: Language, to target: TargetLanguage) async throws -> String {
        calls.append(text)
        if let error { throw error }
        return result
    }
}

private enum StubError: Error {
    case papagoDown
}

@Suite
struct CascadeTranslatorTests {
    private final class EventSink: @unchecked Sendable {
        var events: [CascadeEvent] = []
    }

    private let calendar = Calendar(identifier: .gregorian)
    private let date: Date = {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 8, day: 11, hour: 12))!
    }()

    private func makeCascade(
        papago: StubPapagoTranslator,
        store: InMemoryTranslationQuotaStore,
        networkAvailable: Bool = true,
        quota: TranslationQuota? = nil
    ) -> CascadeTranslator {
        if let quota {
            store.save(quota)
        }
        let tracker = TranslationQuotaTracker(
            dailyLimit: quota?.dailyLimit ?? 10_000,
            storage: store,
            calendar: calendar
        )
        return CascadeTranslator(
            onDevice: { text, _ in "온디바이스 \(text)" },
            papago: papago,
            quotaTracker: tracker,
            isNetworkAvailable: { networkAvailable }
        )
    }

    @Test("쿼터가 남아 있고 네트워크가 되면 Papago 결과를 쓴다")
    func usesPapagoWhenAvailable() async throws {
        let papago = StubPapagoTranslator()
        let cascade = makeCascade(papago: papago, store: InMemoryTranslationQuotaStore())
        let text = try await cascade.translate("こんにちは", from: .japanese, asOf: date)
        #expect(text == "Papago 번역문")
        #expect(papago.calls == ["こんにちは"])
    }

    @Test("Papago 사용 시 쿼터를 소비한다")
    func papagoUsageConsumesQuota() async throws {
        let store = InMemoryTranslationQuotaStore()
        let cascade = makeCascade(papago: StubPapagoTranslator(), store: store)
        _ = try await cascade.translate("こんにちは", from: .japanese, asOf: date)
        #expect(store.load()?.usedCharacters == 5)
    }

    @Test("쿼터가 소진되면 온디바이스로 폴백하고 알린다")
    func fallsBackToOnDeviceWhenQuotaExhausted() async throws {
        let store = InMemoryTranslationQuotaStore()
        let sink = EventSink()
        let cascade = makeCascade(
            papago: StubPapagoTranslator(),
            store: store,
            quota: TranslationQuota(dailyLimit: 10_000, usedCharacters: 10_000, dayIdentifier: "2026-08-11")
        )
        cascade.onEvent = { sink.events.append($0) }
        let text = try await cascade.translate("こんにちは", from: .japanese, asOf: date)
        #expect(text == "온디바이스 こんにちは")
        #expect(sink.events.contains(.fellBackToOnDevice(reason: .quotaExhausted)))
    }

    @Test("네트워크가 없으면 온디바이스로 폴백하고 알린다")
    func fallsBackWhenNetworkUnavailable() async throws {
        let store = InMemoryTranslationQuotaStore()
        let sink = EventSink()
        let cascade = makeCascade(
            papago: StubPapagoTranslator(),
            store: store,
            networkAvailable: false
        )
        cascade.onEvent = { sink.events.append($0) }
        let text = try await cascade.translate("Hello", from: .english, asOf: date)
        #expect(text == "온디바이스 Hello")
        #expect(sink.events.contains(.fellBackToOnDevice(reason: .networkUnavailable)))
    }

    @Test("Papago 오류 시 온디바이스로 폴백하고 쿼터를 소비하지 않는다")
    func fallsBackOnPapagoErrorWithoutConsumingQuota() async throws {
        let store = InMemoryTranslationQuotaStore()
        let sink = EventSink()
        let cascade = makeCascade(papago: StubPapagoTranslator(error: StubError.papagoDown), store: store)
        cascade.onEvent = { sink.events.append($0) }
        let text = try await cascade.translate("Hello", from: .english, asOf: date)
        #expect(text == "온디바이스 Hello")
        #expect(sink.events.contains(.fellBackToOnDevice(reason: .papagoError)))
        #expect(store.load()?.usedCharacters == nil)
    }

    @Test("쿼터가 얼마 안 남으면 Papago를 건너뛰고 온디바이스로 간다")
    func skipsPapagoWhenRemainingIsInsufficient() async throws {
        let papago = StubPapagoTranslator()
        let store = InMemoryTranslationQuotaStore()
        let cascade = makeCascade(
            papago: papago,
            store: store,
            quota: TranslationQuota(dailyLimit: 10_000, usedCharacters: 9_999, dayIdentifier: "2026-08-11")
        )
        let text = try await cascade.translate("こんにちは", from: .japanese, asOf: date)
        #expect(text == "온디바이스 こんにちは")
        #expect(papago.calls.isEmpty)
    }
}