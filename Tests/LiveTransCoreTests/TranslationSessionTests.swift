import Testing
import LiveTransCore

@Suite
struct TranslationSessionTests {
    private func makeSession(
        initialState: TranslationSessionState = .ended
    ) -> (session: TranslationSession, persistence: InMemoryTranslationSessionPersistence) {
        let persistence = InMemoryTranslationSessionPersistence(initialState: initialState)
        return (TranslationSession(persistence: persistence), persistence)
    }

    @Test("시작 전에는 세션이 종료됨 상태이다")
    func startsEnded() {
        let (session, _) = makeSession()
        #expect(session.state == .ended)
    }

    @Test("토글 on 시 세션이 시작됨 상태가 된다")
    func toggleStartsSession() {
        let (session, _) = makeSession()
        session.toggle()
        #expect(session.state == .active)
    }

    @Test("토글 off 시 세션이 종료됨 상태가 된다")
    func toggleStopsSession() {
        let (session, _) = makeSession(initialState: .active)
        session.toggle()
        #expect(session.state == .ended)
    }

    @Test("start는 활성 상태로 만든다")
    func startActivates() {
        let (session, _) = makeSession()
        session.start()
        #expect(session.state == .active)
    }

    @Test("stop은 종료 상태로 만든다")
    func stopEnds() {
        let (session, _) = makeSession(initialState: .active)
        session.stop()
        #expect(session.state == .ended)
    }

    @Test("세션이 active일 때 상태 변화가 알려진다")
    func stateChangeNotifiesObserver() {
        let (session, _) = makeSession()
        var observed: [TranslationSessionState] = []
        session.onStateChange = { observed.append($0) }
        session.start()
        session.stop()
        #expect(observed == [.starting, .active, .stopping, .ended])
    }

    @Test("토글 상태는 앱 재시작 후에도 유지된다")
    func stateSurvivesRestart() {
        let persistence = InMemoryTranslationSessionPersistence(initialState: .ended)
        let firstRun = TranslationSession(persistence: persistence)
        firstRun.start()

        let secondRun = TranslationSession(persistence: persistence)
        #expect(secondRun.state == .active)
    }

    @Test("paused 상태에서는 active로만 resume할 수 있다")
    func pauseResumeLifecycle() {
        let (session, _) = makeSession(initialState: .active)
        session.pause()
        #expect(session.state == .paused)
        session.pause()
        #expect(session.state == .paused)
        session.resume()
        #expect(session.state == .active)
    }

    @Test("paused 상태에서 토글하면 종료된다")
    func toggleFromPausedEnds() {
        let (session, _) = makeSession(initialState: .paused)
        session.toggle()
        #expect(session.state == .ended)
    }
}