import Foundation

public struct CapturedScreen<Payload: Sendable>: Sendable {
    public let fingerprint: String
    public let capturedAt: Date
    public let payload: Payload

    public init(fingerprint: String, capturedAt: Date, payload: Payload) {
        self.fingerprint = fingerprint
        self.capturedAt = capturedAt
        self.payload = payload
    }
}