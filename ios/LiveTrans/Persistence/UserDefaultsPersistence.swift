import Foundation
import LiveTransCore

struct UserDefaultsSessionPersistence: TranslationSessionPersisting {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TranslationSessionState {
        let raw = defaults.string(forKey: "LiveTrans.sessionState")
        let map: [String: TranslationSessionState] = [
            "ended": .ended,
            "starting": .starting,
            "active": .active,
            "paused": .paused,
            "stopping": .stopping,
        ]
        return map[raw ?? ""] ?? .ended
    }

    func save(_ state: TranslationSessionState) {
        let raw: String
        switch state {
        case .ended: raw = "ended"
        case .starting: raw = "starting"
        case .active: raw = "active"
        case .paused: raw = "paused"
        case .stopping: raw = "stopping"
        }
        defaults.set(raw, forKey: "LiveTrans.sessionState")
    }
}

struct UserDefaultsOnboardingPersistence: OnboardingPersisting {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> OnboardingState {
        let raw = defaults.string(forKey: "LiveTrans.onboardingState") ?? ""
        switch raw {
        case "permissionRequested": return .permissionRequested
        case "completed": return .completed
        default: return .notStarted
        }
    }

    func save(_ state: OnboardingState) {
        let raw: String
        switch state {
        case .notStarted: raw = "notStarted"
        case .permissionRequested: raw = "permissionRequested"
        case .completed: raw = "completed"
        }
        defaults.set(raw, forKey: "LiveTrans.onboardingState")
    }
}

struct UserDefaultsQuotaStorage: TranslationQuotaStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TranslationQuota? {
        guard let dayIdentifier = defaults.string(forKey: "LiveTrans.quota.day"),
              defaults.object(forKey: "LiveTrans.quota.used") != nil
        else { return nil }
        return TranslationQuota(
            dailyLimit: TranslationQuotaTracker.defaultDailyLimit,
            usedCharacters: defaults.integer(forKey: "LiveTrans.quota.used"),
            dayIdentifier: dayIdentifier
        )
    }

    func save(_ quota: TranslationQuota) {
        defaults.set(quota.dayIdentifier, forKey: "LiveTrans.quota.day")
        defaults.set(quota.usedCharacters, forKey: "LiveTrans.quota.used")
    }
}

final class PapagoCredentialStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> (clientID: String, clientSecret: String)? {
        let bundleID = defaults.string(forKey: "LiveTrans.papago.clientID")
        let secret = defaults.string(forKey: "LiveTrans.papago.clientSecret")
        if let bundleID = firstNonEmpty(bundleID), let secret = firstNonEmpty(secret) {
            return (bundleID, secret)
        }
        return nil
    }

    func save(clientID: String, clientSecret: String) {
        defaults.set(clientID, forKey: "LiveTrans.papago.clientID")
        defaults.set(clientSecret, forKey: "LiveTrans.papago.clientSecret")
    }

    private func firstNonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}