import Foundation
import CoreMedia
import LiveTransCore

enum SampleBufferFactory {
    static func makeFormatDescription(mediaSubType: UInt32, sps: Data, pps: Data) -> CMVideoFormatDescription? {
        var formatDescription: CMVideoFormatDescription?
        if mediaSubType == kCMVideoCodecType_H264 {
            let parameterSets: [Data] = [sps, pps]
            var pointers: [UnsafePointer<UInt8>] = []
            var sizes: [Int] = []
            for data in parameterSets {
                data.withUnsafeBytes { rawBuffer in
                    pointers.append(rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self))
                    sizes.append(rawBuffer.count)
                }
            }
            let status = pointers.withUnsafeBufferPointer { ptrPtr in
                sizes.withUnsafeBufferPointer { sizePtr in
                    CMVideoFormatDescriptionCreateFromH264ParameterSets(
                        allocator: nil,
                        parameterSetCount: parameterSets.count,
                        parameterSetPointers: ptrPtr.baseAddress!,
                        parameterSetSizes: sizePtr.baseAddress!,
                        nalUnitHeaderLength: 4,
                        formatDescriptionOut: &formatDescription
                    )
                }
            }
            guard status == noErr else { return nil }
            return formatDescription
        }
        return nil
    }

    static func makeSampleBuffer(
        formatDescription: CMVideoFormatDescription,
        data: Data,
        presentationTime: CMTime
    ) -> CMSampleBuffer? {
        var blockBuffer: CMBlockBuffer?
        let status = data.withUnsafeBytes { rawBuffer in
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: UnsafeMutableRawPointer(mutating: rawBuffer.baseAddress!),
                blockLength: rawBuffer.count,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: rawBuffer.count,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
        }
        guard status == noErr, let blockBuffer else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: CMTime.invalid
        )
        var sampleSize = data.count
        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )
        guard sampleStatus == noErr else { return nil }
        return sampleBuffer
    }

    static var hostClock: CMClock { CMClockGetHostTimeClock() }
}