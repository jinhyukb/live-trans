public final class TranslationSession {
    public private(set) var state: TranslationSessionState

    private let persistence: any TranslationSessionPersisting

    public var onStateChange: ((TranslationSessionState) -> Void)?

    public init(persistence: any TranslationSessionPersisting) {
        self.persistence = persistence
        self.state = persistence.load()
    }

    public func start() {
        guard state == .ended || state == .stopping else { return }
        transition(to: .starting)
        transition(to: .active)
    }

    public func stop() {
        guard state == .active || state == .paused || state == .starting else { return }
        transition(to: .stopping)
        transition(to: .ended)
    }

    public func pause() {
        guard state == .active else { return }
        transition(to: .paused)
    }

    public func resume() {
        guard state == .paused else { return }
        transition(to: .active)
    }

    public func toggle() {
        switch state {
        case .ended, .stopping:
            start()
        case .active, .paused, .starting:
            stop()
        }
    }

    private func transition(to newState: TranslationSessionState) {
        guard newState != state else { return }
        state = newState
        persistence.save(newState)
        onStateChange?(newState)
    }
}