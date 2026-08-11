import Testing
import LiveTransCore

@Suite
struct OnboardingFlowTests {
    @Test("첫 실행에는 온보딩이 필요하다")
    func firstRunNeedsOnboarding() {
        let flow = OnboardingFlow(persistence: InMemoryOnboardingPersistence())
        #expect(flow.needsOnboarding)
        #expect(flow.state == .notStarted)
    }

    @Test("begin하면 권한 안내 상태가 되고 저장된다")
    func beginRequestsPermission() {
        let persistence = InMemoryOnboardingPersistence()
        let flow = OnboardingFlow(persistence: persistence)
        flow.begin()
        #expect(flow.state == .permissionRequested)
        #expect(persistence.savedStates == [.permissionRequested])
    }

    @Test("complete하면 온보딩이 끝났고 저장된다")
    func completeFinishesOnboarding() {
        let persistence = InMemoryOnboardingPersistence()
        let flow = OnboardingFlow(persistence: persistence)
        flow.begin()
        flow.complete()
        #expect(flow.state == .completed)
        #expect(!flow.needsOnboarding)
        #expect(persistence.savedStates == [.permissionRequested, .completed])
    }

    @Test("온보딩 완료 상태는 앱 재시작 후에도 유지된다")
    func completionSurvivesRestart() {
        let persistence = InMemoryOnboardingPersistence(initialState: .completed)
        let flow = OnboardingFlow(persistence: persistence)
        #expect(!flow.needsOnboarding)
        #expect(flow.state == .completed)
    }

    @Test("완료 후 begin해도 상태가 되돌아가지 않는다")
    func beginIsNoopAfterCompletion() {
        let flow = OnboardingFlow(persistence: InMemoryOnboardingPersistence(initialState: .completed))
        flow.begin()
        #expect(flow.state == .completed)
    }
}
