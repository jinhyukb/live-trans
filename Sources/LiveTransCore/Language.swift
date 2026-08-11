public enum Language: String, Equatable, Sendable {
    case english
    case japanese
    case korean
    case undetermined
}

public enum TargetLanguage: String, Equatable, Sendable {
    case korean = "ko"
}

public extension Language {
    var papagoSourceCode: String? {
        switch self {
        case .english: return "en"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .undetermined: return nil
        }
    }
}