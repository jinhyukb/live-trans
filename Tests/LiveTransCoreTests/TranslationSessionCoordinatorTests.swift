import Foundation
import Testing
import LiveTransCore

@Suite
struct TranslationSessionCoordinatorTests {
    private final class ActivitySink: @unchecked Sendable {
        var activities: [CaptureActivity] = []
    }

    private func makeCoordinator(
        sessionInitial: TranslationSessionState = .ended,
        onboardingInitial: OnboardingState = .notStarted
    ) -> (
        coordinator: TranslationSessionCoordinator,
        session: TranslationSession,
        onboarding: OnboardingFlow
    ) {
        let session = TranslationSession(
            persistence: InMemoryTranslationSessionPersistence(initialState: sessionInitial)
        )
        let onboarding = OnboardingFlow(
            persistence: InMemoryOnboardingPersistence(initialState: onboardingInitial)
        )
        return (TranslationSessionCoordinator(session: session, onboarding: onboarding), session, onboarding)
    }

    @Test("첫 실행에서 토글하면 온보딩을 먼저 요청하고 세션은 시작하지 않는다")
    func toggleOnFirstRunRequestsOnboarding() {
        let (coordinator, session, onboarding) = makeCoordinator()
        coordinator.toggle()
        #expect(onboarding.state == .permissionRequested)
        #expect(session.state == .ended)
    }

    @Test("온보딩 완료 시 대기 중이던 세션 시작이 이어진다")
    func completingOnboardingStartsPendingSession() {
        let (coordinator, session, onboarding) = makeCoordinator()
        coordinator.toggle()
        coordinator.completeOnboarding()
        #expect(onboarding.state == .completed)
        #expect(session.state == .active)
    }

    @Test("온보딩이 끝난 뒤 토글하면 바로 세션이 시작된다")
    func toggleAfterOnboardingStartsSession() {
        let (coordinator, session, _) = makeCoordinator(onboardingInitial: .completed)
        coordinator.toggle()
        #expect(session.state == .active)
    }

    @Test("active 상태에서 토글하면 세션을 종료한다")
    func toggleStopsActiveSession() {
        let (coordinator, session, _) = makeCoordinator(
            sessionInitial: .active,
            onboardingInitial: .completed
        )
        coordinator.toggle()
        #expect(session.state == .ended)
    }

    @Test("세션이 active가 아니면 캡처 활동은 standby다")
    func observeScreenWhileInactiveReturnsStandby() {
        let (coordinator, _, _) = makeCoordinator()
        let activity = coordinator.observeScreen(fingerprint: "A", at: Date(timeIntervalSince1970: 1000))
        #expect(activity == .standby)
    }

    @Test("active 세션에서 화면 변화를 관찰하면 캡처 활동이 알려진다")
    func observeScreenDuringActiveSessionEmitsActivity() {
        let (coordinator, _, _) = makeCoordinator(onboardingInitial: .completed)
        coordinator.toggle()
        let sink = ActivitySink()
        coordinator.onCaptureActivityChange = { sink.activities.append($0) }

        let t0 = Date(timeIntervalSince1970: 1000)
        #expect(coordinator.observeScreen(fingerprint: "A", at: t0) == .active)
        #expect(coordinator.observeScreen(fingerprint: "B", at: t0.addingTimeInterval(1)) == .active)
        #expect(sink.activities == [.active])
    }

    @Test("세션이 종료되면 캡처 활동은 standby로 멈춘다")
    func stoppingSessionStopsCaptureActivity() {
        let (coordinator, _, _) = makeCoordinator(onboardingInitial: .completed)
        coordinator.toggle()
        let sink = ActivitySink()
        coordinator.onCaptureActivityChange = { sink.activities.append($0) }
        let t0 = Date(timeIntervalSince1970: 1000)
        _ = coordinator.observeScreen(fingerprint: "A", at: t0)
        coordinator.toggle()
        _ = coordinator.observeScreen(fingerprint: "A", at: t0.addingTimeInterval(1))
        #expect(sink.activities == [.active, .standby])
    }
}
