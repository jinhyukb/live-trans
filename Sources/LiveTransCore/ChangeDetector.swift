import Foundation

public struct ChangeDetectionConfig: Equatable, Sendable {
    public var minimumInterval: TimeInterval
    public var sameFingerprintHoldInterval: TimeInterval
    public var maxFramesPerWindow: Int
    public var windowDuration: TimeInterval

    public init(
        minimumInterval: TimeInterval = 0.4,
        sameFingerprintHoldInterval: TimeInterval = 2.0,
        maxFramesPerWindow: Int = 12,
        windowDuration: TimeInterval = 10.0
    ) {
        self.minimumInterval = minimumInterval
        self.sameFingerprintHoldInterval = sameFingerprintHoldInterval
        self.maxFramesPerWindow = maxFramesPerWindow
        self.windowDuration = windowDuration
    }
}

public final class ChangeDetector: @unchecked Sendable {
    private let config: ChangeDetectionConfig
    private var lastProcessedAt: Date?
    private var lastProcessedFingerprint: String?
    private var processedTimestamps: [Date] = []

    public init(config: ChangeDetectionConfig = ChangeDetectionConfig()) {
        self.config = config
    }

    public func shouldProcess(fingerprint: String, at date: Date) -> Bool {
        if let last = lastProcessedAt, date.timeIntervalSince(last) < config.minimumInterval {
            return false
        }

        pruneWindow(relativeTo: date)
        if processedTimestamps.count >= config.maxFramesPerWindow {
            return false
        }

        if fingerprint == lastProcessedFingerprint,
           let last = lastProcessedAt,
           date.timeIntervalSince(last) < config.sameFingerprintHoldInterval {
            return false
        }

        lastProcessedAt = date
        lastProcessedFingerprint = fingerprint
        processedTimestamps.append(date)
        return true
    }

    private func pruneWindow(relativeTo date: Date) {
        processedTimestamps.removeAll { date.timeIntervalSince($0) > config.windowDuration }
    }
}