import LiveTransCore

final class InMemoryOnboardingPersistence: OnboardingPersisting {
    private(set) var savedStates: [OnboardingState] = []
    private var storedState: OnboardingState

    init(initialState: OnboardingState = .notStarted) {
        self.storedState = initialState
    }

    func load() -> OnboardingState {
        storedState
    }

    func save(_ state: OnboardingState) {
        storedState = state
        savedStates.append(state)
    }
}
