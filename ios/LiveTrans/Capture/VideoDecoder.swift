import Foundation
@preconcurrency import CoreMedia
import CoreVideo
import VideoToolbox

struct DecodedFrame: @unchecked Sendable {
    let sampleBuffer: CMSampleBuffer?
}

final class VideoDecoder: @unchecked Sendable {
    private var session: VTDecompressionSession?
    private var formatDescription: CMFormatDescription?
    private let queue = DispatchQueue(label: "live-trans.decoder")

    func decode(_ sampleBuffer: CMSampleBuffer) async -> DecodedFrame {
        let format = CMSampleBufferGetFormatDescription(sampleBuffer)
        let box = SampleBufferBox(sampleBuffer)
        return await withCheckedContinuation { continuation in
            queue.async { [self] in
                self.finishDecode(box.value, format: format, continuation: continuation)
            }
        }
    }

    private func finishDecode(
        _ sampleBuffer: CMSampleBuffer,
        format: CMFormatDescription?,
        continuation: CheckedContinuation<DecodedFrame, Never>
    ) {
        if let format,
           session == nil || !CMFormatDescriptionEqual(formatDescription, otherFormatDescription: format) {
            self.formatDescription = format
            createSession(with: format)
        }
        guard let session else {
            continuation.resume(returning: DecodedFrame(sampleBuffer: nil))
            return
        }

        let outputBox = PixelBufferBox()
        let status = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: [],
            infoFlagsOut: nil,
            outputHandler: { _, _, imageBuffer, _, _ in
                outputBox.set(imageBuffer)
            }
        )
        guard status == noErr, let output = outputBox.current else {
            continuation.resume(returning: DecodedFrame(sampleBuffer: nil))
            return
        }

        var formatDescriptionOut: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: output,
            formatDescriptionOut: &formatDescriptionOut
        )
        guard formatStatus == noErr, let formatDescriptionOut else {
            continuation.resume(returning: DecodedFrame(sampleBuffer: nil))
            return
        }

        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            decodeTimeStamp: .invalid
        )
        var newSample: CMSampleBuffer?
        let convertStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: output,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescriptionOut,
            sampleTiming: &timing,
            sampleBufferOut: &newSample
        )
        continuation.resume(returning: DecodedFrame(sampleBuffer: convertStatus == noErr ? newSample : nil))
    }

    private func createSession(with format: CMFormatDescription) {
        let pixelBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA
        ]
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: format,
            decoderSpecification: nil,
            imageBufferAttributes: pixelBufferAttributes as CFDictionary,
            outputCallback: nil,
            decompressionSessionOut: &session
        )
        if status != noErr {
            session = nil
        }
    }
}

private final class SampleBufferBox: @unchecked Sendable {
    let value: CMSampleBuffer

    init(_ value: CMSampleBuffer) {
        self.value = value
    }
}

private final class PixelBufferBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: CVPixelBuffer?

    func set(_ buffer: CVPixelBuffer?) {
        lock.lock()
        defer { lock.unlock() }
        value = buffer
    }

    var current: CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
