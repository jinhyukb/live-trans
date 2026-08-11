import Foundation
import Network
import ReplayKit
@preconcurrency import CoreMedia

final class SampleHandler: RPBroadcastSampleHandler, @unchecked Sendable {
    private var connection: NWConnection?
    private var didSendFormat = false
    private var lastSentFrameAt = Date.distantPast
    private let minimumFrameInterval = 1.0 / 20.0
    private let queue = DispatchQueue(label: "live-trans.broadcast")

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        let connection = NWConnection(
            host: NWEndpoint.Host("127.0.0.1"),
            port: NWEndpoint.Port(integerLiteral: 19_642),
            using: .tcp
        )
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error), .waiting(let error):
                print("[LiveTrans] loopback connect failed: \(error)")
                self?.finishBroadcastWithError(error)
            case .cancelled:
                self?.connection = nil
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video, let connection else { return }

        let now = Date()
        guard now.timeIntervalSince(lastSentFrameAt) >= minimumFrameInterval else { return }
        lastSentFrameAt = now

        if !didSendFormat {
            didSendFormat = sendFormatDescription(for: sampleBuffer, to: connection)
        }
        sendVideoFrame(sampleBuffer, to: connection)
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        connection?.cancel()
        connection = nil
    }

    private func sendFormatDescription(for sampleBuffer: CMSampleBuffer, to connection: NWConnection) -> Bool {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return false }
        let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)

        var spsData: Data?
        var ppsData: Data?
        var nalHeaderLength: Int = 4

        if mediaSubType == kCMVideoCodecType_H264 {
            var spsSize = 0
            var spsCount = 0
            var sps: UnsafePointer<UInt8>?
            var nalHeaderLength: Int32 = 4
            var status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDescription,
                parameterSetIndex: 0,
                parameterSetPointerOut: &sps,
                parameterSetSizeOut: &spsSize,
                parameterSetCountOut: &spsCount,
                nalUnitHeaderLengthOut: &nalHeaderLength
            )
            if status == noErr, let sps {
                spsData = Data(bytes: sps, count: spsSize)
            }
            var pps: UnsafePointer<UInt8>?
            var ppsSize = 0
            var ppsCount = 0
            var ppsNalHeader: Int32 = 4
            status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDescription,
                parameterSetIndex: 1,
                parameterSetPointerOut: &pps,
                parameterSetSizeOut: &ppsSize,
                parameterSetCountOut: &ppsCount,
                nalUnitHeaderLengthOut: &ppsNalHeader
            )
            if status == noErr, let pps {
                ppsData = Data(bytes: pps, count: ppsSize)
            }
        }

        guard let spsData, let ppsData else { return false }

        var payload = Data()
        var magic = UInt32(mediaSubType).bigEndian
        withUnsafeBytes(of: &magic) { payload.append(contentsOf: $0) }
        withUnsafeBytes(of: &nalHeaderLength) { payload.append(Data($0)) }
        writeLengthPrefixed(&payload, payload: spsData)
        writeLengthPrefixed(&payload, payload: ppsData)

        send(.format, payload: payload, on: connection)
        return true
    }

    private func sendVideoFrame(_ sampleBuffer: CMSampleBuffer, to connection: NWConnection) {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var length = 0
        var pointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &length,
            totalLengthOut: nil,
            dataPointerOut: &pointer
        )
        guard status == noErr, let pointer, length > 0 else { return }

        let raw = Data(bytes: pointer, count: length)
        send(.frame, payload: raw, on: connection)
    }

    private func writeLengthPrefixed(_ data: inout Data, payload: Data) {
        var length = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
        data.append(payload)
    }

    private func send(_ type: CaptureWireMessageType, payload: Data, on connection: NWConnection) {
        let message = CaptureWire.encode(type, payload: payload)
        connection.send(content: message, completion: .contentProcessed { _ in })
    }
}