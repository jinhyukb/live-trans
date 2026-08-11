import LiveTransCore

final class InMemoryTranslationSessionPersistence: TranslationSessionPersisting {
    private(set) var savedStates: [TranslationSessionState] = []
    private var storedState: TranslationSessionState
    private var onLoadCalled = false

    init(initialState: TranslationSessionState = .ended) {
        self.storedState = initialState
    }

    func load() -> TranslationSessionState {
        onLoadCalled = true
        return storedState
    }

    func save(_ state: TranslationSessionState) {
        storedState = state
        savedStates.append(state)
    }
}