import Foundation
@preconcurrency import Translation
import LiveTransCore

enum TranslationUnavailableError: Error {
    case unsupportedSource
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
        let configuration = Translation.TranslationSession.Configuration(
            source: appleLanguage(for: source),
            target: appleTargetLanguage(for: target)
        )
        guard let session = lockedSession else {
            throw TranslationUnavailableError.translationNotReady
        }
        let response = try await session.translate(text, using: configuration)
        return response.targetText
    }

    private var lockedSession: Translation.TranslationSession? {
        lock.lock()
        defer { lock.unlock() }
        return session
    }

    private func appleLanguage(for language: Language) -> Locale.Language? {
        switch language {
        case .english: return Locale.Language(identifier: "en")
        case .japanese: return Locale.Language(identifier: "ja")
        case .korean: return Locale.Language(identifier: "ko")
        case .undetermined: return nil
        }
    }

    private func appleTargetLanguage(for target: TargetLanguage) -> Locale.Language? {
        switch target {
        case .korean: return Locale.Language(identifier: "ko")
        }
    }
}