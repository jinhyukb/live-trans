import Foundation
import Testing
import LiveTransCore

@Suite
struct ChangeDetectorTests {
    private let t0 = Date(timeIntervalSince1970: 1000)

    @Test("같은 화면은 hold 구간 동안 재처리하지 않는다")
    func sameFingerprintWithinHoldIsSkipped() {
        let detector = ChangeDetector()
        #expect(detector.shouldProcess(fingerprint: "A", at: t0))
        #expect(!detector.shouldProcess(fingerprint: "A", at: t0.addingTimeInterval(0.5)))
    }

    @Test("화면이 바뀌면 즉시 재처리한다")
    func changedFingerprintProcessesImmediately() {
        let detector = ChangeDetector()
        #expect(detector.shouldProcess(fingerprint: "A", at: t0))
        #expect(detector.shouldProcess(fingerprint: "B", at: t0.addingTimeInterval(0.5)))
    }

    @Test("hold 구간이 지난 같은 화면은 재처리한다")
    func sameFingerprintAfterHoldIsProcessed() {
        var config = ChangeDetectionConfig()
        config.sameFingerprintHoldInterval = 1.0
        let detector = ChangeDetector(config: config)
        #expect(detector.shouldProcess(fingerprint: "A", at: t0))
        #expect(!detector.shouldProcess(fingerprint: "A", at: t0.addingTimeInterval(0.5)))
        #expect(detector.shouldProcess(fingerprint: "A", at: t0.addingTimeInterval(1.5)))
    }

    @Test("minimumInterval보다 자주 오는 프레임은 무시한다")
    func framesBelowMinimumIntervalAreSkipped() {
        var config = ChangeDetectionConfig()
        config.minimumInterval = 1.0
        let detector = ChangeDetector(config: config)
        #expect(detector.shouldProcess(fingerprint: "A", at: t0))
        #expect(detector.shouldProcess(fingerprint: "B", at: t0.addingTimeInterval(0.2)) == false)
        #expect(detector.shouldProcess(fingerprint: "C", at: t0.addingTimeInterval(1.1)))
    }

    @Test("창구간 내 최대 처리 횟수를 넘기면 막는다")
    func maxFramesPerWindowCapsProcessing() {
        var config = ChangeDetectionConfig()
        config.maxFramesPerWindow = 2
        config.minimumInterval = 0
        config.sameFingerprintHoldInterval = 0
        let detector = ChangeDetector(config: config)
        #expect(detector.shouldProcess(fingerprint: "A", at: t0))
        #expect(detector.shouldProcess(fingerprint: "B", at: t0.addingTimeInterval(0.1)))
        #expect(detector.shouldProcess(fingerprint: "C", at: t0.addingTimeInterval(0.2)) == false)
    }
}