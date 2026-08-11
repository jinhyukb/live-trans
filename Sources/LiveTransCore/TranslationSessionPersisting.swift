public protocol TranslationSessionPersisting {
    func load() -> TranslationSessionState
    func save(_ state: TranslationSessionState)
}