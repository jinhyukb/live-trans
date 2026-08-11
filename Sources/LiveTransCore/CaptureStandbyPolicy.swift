import Foundation

public enum CaptureActivity: Equatable, Sendable {
    case active
    case standby
}

public struct CaptureStandbyConfig: Equatable, Sendable {
    public var standbyAfterIdleInterval: TimeInterval

    public init(standbyAfterIdleInterval: TimeInterval = 10.0) {
        self.standbyAfterIdleInterval = standbyAfterIdleInterval
    }
}

public final class CaptureStandbyPolicy: @unchecked Sendable {
    private let config: CaptureStandbyConfig
    private var lastChangedAt: Date?
    private var lastFingerprint: String?

    public init(config: CaptureStandbyConfig = CaptureStandbyConfig()) {
        self.config = config
    }

    public func activity(after fingerprint: String, at date: Date) -> CaptureActivity {
        guard fingerprint != lastFingerprint else {
            if let lastChangedAt, date.timeIntervalSince(lastChangedAt) >= config.standbyAfterIdleInterval {
                return .standby
            }
            return .active
        }

        lastFingerprint = fingerprint
        lastChangedAt = date
        return .active
    }

    public func reset() {
        lastFingerprint = nil
        lastChangedAt = nil
    }
}
