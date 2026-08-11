import Foundation

public protocol PapagoTranslating: Sendable {
    func translate(_ text: String, from source: Language, to target: TargetLanguage) async throws -> String
}

public enum CascadeEvent: Equatable, Sendable {
    case usedPapago(characters: Int)
    case fellBackToOnDevice(reason: CascadeFallbackReason)
}

public enum CascadeFallbackReason: Equatable, Sendable {
    case quotaExhausted
    case networkUnavailable
    case papagoError
}

public final class CascadeTranslator: @unchecked Sendable {
    public typealias OnDeviceTranslator = @Sendable (String, Language) async throws -> String
    public typealias NetworkAvailability = @Sendable () async -> Bool

    private let onDevice: OnDeviceTranslator
    private let papago: any PapagoTranslating
    private let quotaTracker: TranslationQuotaTracker
    private let isNetworkAvailable: NetworkAvailability

    public var onEvent: (@Sendable (CascadeEvent) -> Void)?

    public init(
        onDevice: @escaping OnDeviceTranslator,
        papago: any PapagoTranslating,
        quotaTracker: TranslationQuotaTracker,
        isNetworkAvailable: @escaping NetworkAvailability = { true }
    ) {
        self.onDevice = onDevice
        self.papago = papago
        self.quotaTracker = quotaTracker
        self.isNetworkAvailable = isNetworkAvailable
    }

    public func translate(
        _ text: String,
        from source: Language,
        to target: TargetLanguage = .korean,
        asOf date: Date = Date()
    ) async throws -> String {
        let quota = quotaTracker.currentQuota(asOf: date)
        if quota.remainingCharacters < text.count {
            emitFallback(.quotaExhausted)
            return try await onDevice(text, source)
        }

        guard await isNetworkAvailable() else {
            emitFallback(.networkUnavailable)
            return try await onDevice(text, source)
        }

        do {
            let result = try await papago.translate(text, from: source, to: target)
            quotaTracker.consume(text.count, asOf: date)
            onEvent?(.usedPapago(characters: text.count))
            return result
        } catch {
            emitFallback(.papagoError)
            return try await onDevice(text, source)
        }
    }

    private func emitFallback(_ reason: CascadeFallbackReason) {
        onEvent?(.fellBackToOnDevice(reason: reason))
    }
}