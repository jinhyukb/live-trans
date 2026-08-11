import Foundation
import Testing
import LiveTransCore

@Suite
struct CaptureStandbyPolicyTests {
    private let t0 = Date(timeIntervalSince1970: 1000)

    @Test("화면이 바뀌면 active로 유지한다")
    func changedFingerprintStaysActive() {
        let policy = CaptureStandbyPolicy()
        #expect(policy.activity(after: "A", at: t0) == .active)
        #expect(policy.activity(after: "B", at: t0.addingTimeInterval(1)) == .active)
    }

    @Test("같은 화면이 idle 기준을 넘기면 standby로 전환한다")
    func sameFingerprintOverIdleGoesStandby() {
        var config = CaptureStandbyConfig()
        config.standbyAfterIdleInterval = 5.0
        let policy = CaptureStandbyPolicy(config: config)
        _ = policy.activity(after: "A", at: t0)
        #expect(policy.activity(after: "A", at: t0.addingTimeInterval(6)) == .standby)
    }

    @Test("idle 기준 이내의 같은 화면은 active를 유지한다")
    func sameFingerprintWithinIdleStaysActive() {
        var config = CaptureStandbyConfig()
        config.standbyAfterIdleInterval = 5.0
        let policy = CaptureStandbyPolicy(config: config)
        _ = policy.activity(after: "A", at: t0)
        #expect(policy.activity(after: "A", at: t0.addingTimeInterval(3)) == .active)
    }

    @Test("standby 상태에서 화면이 바뀌면 다시 active로 깨어난다")
    func changedFingerprintWakesFromStandby() {
        var config = CaptureStandbyConfig()
        config.standbyAfterIdleInterval = 5.0
        let policy = CaptureStandbyPolicy(config: config)
        _ = policy.activity(after: "A", at: t0)
        _ = policy.activity(after: "A", at: t0.addingTimeInterval(6))
        #expect(policy.activity(after: "B", at: t0.addingTimeInterval(7)) == .active)
    }

    @Test("reset하면 같은 화면도 다시 active로 시작한다")
    func resetStartsFresh() {
        var config = CaptureStandbyConfig()
        config.standbyAfterIdleInterval = 5.0
        let policy = CaptureStandbyPolicy(config: config)
        _ = policy.activity(after: "A", at: t0)
        _ = policy.activity(after: "A", at: t0.addingTimeInterval(6))
        policy.reset()
        #expect(policy.activity(after: "A", at: t0.addingTimeInterval(100)) == .active)
    }
}
