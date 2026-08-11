import Foundation
@preconcurrency import Translation
import LiveTransCore

enum TranslationUnavailableError: Error {
    case translationNotReady
}

final class AppleOnDeviceTranslator: @unchecked Sendable {
    private let lock = NSLock()
    private var session: Translation.TranslationSession?

    func adopt(_ session: Translation.TranslationSession) {
        lock.lock()
        defer { lock.unlock() }
        self.session = session
    }

    func translate(
        _ text: String,
        from source: Language,
        to target: TargetLanguage
    ) async throws -> String {
        guard let session = lockedSession else {
            throw TranslationUnavailableError.translationNotReady
        }
        let response = try await session.translate(text)
        return response.targetText
    }

    private var lockedSession: Translation.TranslationSession? {
        lock.lock()
        defer { lock.unlock() }
        return session
    }
}