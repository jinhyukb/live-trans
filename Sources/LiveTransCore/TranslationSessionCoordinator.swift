import Foundation

public final class TranslationSessionCoordinator: @unchecked Sendable {
    public let session: TranslationSession
    public let onboarding: OnboardingFlow

    private let standbyPolicy: CaptureStandbyPolicy
    private var pendingStart = false
    private var lastEmittedActivity: CaptureActivity?

    public var onCaptureActivityChange: (@Sendable (CaptureActivity) -> Void)?
    public var onOnboardingStateChange: (@Sendable (OnboardingState) -> Void)?

    public init(
        session: TranslationSession,
        onboarding: OnboardingFlow,
        standbyPolicy: CaptureStandbyPolicy = CaptureStandbyPolicy()
    ) {
        self.session = session
        self.onboarding = onboarding
        self.standbyPolicy = standbyPolicy
        onboarding.onStateChange = { [weak self] state in
            self?.onOnboardingStateChange?(state)
        }
    }

    public func toggle() {
        switch session.state {
        case .active, .paused, .starting:
            pendingStart = false
            session.stop()
        case .ended, .stopping:
            if onboarding.needsOnboarding {
                pendingStart = true
                onboarding.begin()
            } else {
                session.start()
            }
        }
    }

    public func completeOnboarding() {
        onboarding.complete()
        if pendingStart {
            pendingStart = false
            session.start()
        }
    }

    @discardableResult
    public func observeScreen(fingerprint: String, at date: Date) -> CaptureActivity {
        let activity: CaptureActivity
        if session.state == .active {
            activity = standbyPolicy.activity(after: fingerprint, at: date)
        } else {
            activity = .standby
        }
        if activity != lastEmittedActivity {
            lastEmittedActivity = activity
            onCaptureActivityChange?(activity)
        }
        return activity
    }
}
