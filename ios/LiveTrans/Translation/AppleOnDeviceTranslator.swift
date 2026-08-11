import Foundation
import Translation
import LiveTransCore

struct AppleOnDeviceTranslator: Sendable {
    func translate(_ text: String, from source: Language, to target: TargetLanguage) async throws -> String {
        guard let sourceLanguage = appleLanguage(for: source),
              let targetLanguage = appleLanguage(for: .korean)
        else { throw TranslationUnavailableError.unsupportedSource }

        let configuration = TranslationSession.Configuration(
            source: sourceLanguage,
            target: targetLanguage
        )
        let session = TranslationSession(configuration: configuration)
        let result = try await session.translate(text)
        return result
    }

    private func appleLanguage(for language: Language) -> Translation.Language? {
        switch language {
        case .english: return .init(isoLanguageCode: "en")
        case .japanese: return .init(isoLanguageCode: "ja")
        case .korean: return .init(isoLanguageCode: "ko")
        case .undetermined: return nil
        }
    }
}

enum TranslationUnavailableError: Error {
    case unsupportedSource
}