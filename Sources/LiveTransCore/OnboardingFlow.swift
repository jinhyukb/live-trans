public enum OnboardingState: Equatable, Sendable {
    case notStarted
    case permissionRequested
    case completed
}

public protocol OnboardingPersisting {
    func load() -> OnboardingState
    func save(_ state: OnboardingState)
}

public final class OnboardingFlow: @unchecked Sendable {
    public private(set) var state: OnboardingState

    private let persistence: any OnboardingPersisting

    public var onStateChange: ((OnboardingState) -> Void)?

    public init(persistence: any OnboardingPersisting) {
        self.persistence = persistence
        self.state = persistence.load()
    }

    public var needsOnboarding: Bool {
        state != .completed
    }

    public func begin() {
        guard state == .notStarted else { return }
        transition(to: .permissionRequested)
    }

    public func complete() {
        guard state != .completed else { return }
        transition(to: .completed)
    }

    private func transition(to newState: OnboardingState) {
        state = newState
        persistence.save(newState)
        onStateChange?(newState)
    }
}
