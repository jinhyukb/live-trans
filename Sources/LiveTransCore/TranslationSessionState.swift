public enum TranslationSessionState: Equatable, Sendable {
    case ended
    case starting
    case active
    case paused
    case stopping
}