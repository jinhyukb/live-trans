import Foundation
import Network
@preconcurrency import CoreMedia

final class LoopbackServer: @unchecked Sendable {
    var onSampleBuffer: (@Sendable (CMSampleBuffer) -> Void)?
    var onFormatDescription: (@Sendable (CMVideoFormatDescription) -> Void)?

    private var listener: NWListener?
    private var parser = CaptureWireParser()
    private var sps: Data?
    private var pps: Data?
    private var mediaSubType: UInt32 = kCMVideoCodecType_H264
    private let queue = DispatchQueue(label: "live-trans.loopback")
    private var sampleIndex: Int64 = 0

    func start(port: UInt16) throws {
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        parser = CaptureWireParser()
    }

    private func handle(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                self?.receive(on: connection)
            }
        }
        connection.start(queue: queue)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data {
                self.parser.append(data) { type, payload in
                    switch type {
                    case .format:
                        self.handleFormat(payload)
                    case .frame:
                        self.handleFrame(payload)
                    }
                }
            }
            if error == nil && !isComplete {
                self.receive(on: connection)
            } else {
                connection.cancel()
            }
        }
    }

    private func handleFormat(_ payload: Data) {
        guard payload.count >= 12 else { return }
        mediaSubType = payload.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self) }.bigEndian
        let nalHeaderLength = payload.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: 4, as: Int.self).bigEndian
        }
        _ = nalHeaderLength

        var offset = 12
        let sps = readLengthPrefixed(payload, at: &offset)
        let pps = readLengthPrefixed(payload, at: &offset)
        guard let sps, let pps else { return }
        self.sps = sps
        self.pps = pps

        if let format = SampleBufferFactory.makeFormatDescription(
            mediaSubType: mediaSubType,
            sps: sps,
            pps: pps
        ) {
            onFormatDescription?(format)
        }
    }

    private func handleFrame(_ payload: Data) {
        guard let sps, let pps else { return }
        guard let format = SampleBufferFactory.makeFormatDescription(
            mediaSubType: mediaSubType,
            sps: sps,
            pps: pps
        ) else { return }

        sampleIndex += 1
        let time = CMTime(value: sampleIndex, timescale: 600)
        if let sample = SampleBufferFactory.makeSampleBuffer(
            formatDescription: format,
            data: payload,
            presentationTime: time
        ) {
            onSampleBuffer?(sample)
        }
    }

    private func readLengthPrefixed(_ payload: Data, at offset: inout Int) -> Data? {
        guard payload.count >= offset + 4 else { return nil }
        let length = Int(
            payload.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian }
        )
        offset += 4
        guard payload.count >= offset + length else { return nil }
        let data = payload.subdata(in: offset ..< offset + length)
        offset += length
        return data
    }
}