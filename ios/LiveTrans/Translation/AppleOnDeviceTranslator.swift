import Foundation
import Translation
import LiveTransCore

struct AppleOnDeviceTranslator: Sendable {
    func translate(_ text: String, from source: Language, to target: TargetLanguage) async throws -> String {
        guard let sourceLanguage = appleLanguage(for: source),
              let targetLanguage = appleLanguage(for: .korean)
        else { throw TranslationUnavailableError.unsupportedSource }

        let configuration = Translation.TranslationSession.Configuration(
            source: sourceLanguage,
            target: targetLanguage
        )
        let session = Translation.TranslationSession(configuration: configuration)
        let result = try await session.translate(text)
        return result
    }

    private func appleLanguage(for language: Language) -> Locale.Language? {
        switch language {
        case .english: return Locale.Language(isoLanguageCode: "en")
        case .japanese: return Locale.Language(isoLanguageCode: "ja")
        case .korean: return Locale.Language(isoLanguageCode: "ko")
        case .undetermined: return nil
        }
    }
}

enum TranslationUnavailableError: Error {
    case unsupportedSource
}