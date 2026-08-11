import Foundation
@preconcurrency import CoreMedia
import CoreVideo
import VideoToolbox

final class VideoDecoder: @unchecked Sendable {
    private var session: VTDecompressionSession?
    private var formatDescription: CMFormatDescription?
    private let queue = DispatchQueue(label: "live-trans.decoder")

    func decode(_ sampleBuffer: CMSampleBuffer) async -> CMSampleBuffer? {
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                self.finishDecode(sampleBuffer, continuation: continuation)
            }
        }
    }

    private func finishDecode(
        _ sampleBuffer: CMSampleBuffer,
        continuation: CheckedContinuation<CMSampleBuffer?, Never>
    ) {
        let format = CMSampleBufferGetFormatDescription(sampleBuffer)
        if session == nil || CMFormatDescriptionEqual(formatDescription, format) == false {
            formatDescription = format
            createSession(with: format)
        }
        guard let session else { continuation.resume(returning: nil); return }

        var output: CVPixelBuffer?
        let status = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: [],
            infoFlagsOut: nil,
            outputHandler: { _, _, imageBuffer, _, _ in
                output = imageBuffer
            }
        )
        guard status == noErr, let output else { continuation.resume(returning: nil); return }

        var newSample: CMSampleBuffer?
        let convertStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: output,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescriptionOut: nil,
            sampleBufferOut: &newSample
        )
        if let newSample {
            let timing = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            CMSampleBufferSetPresentationTimeStamp(newSample, at: timing)
        }
        continuation.resume(returning: newSample)
    }

    private func createSession(with format: CMFormatDescription) {
        var pixelBufferAttributes: [CFString: Any] = [
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