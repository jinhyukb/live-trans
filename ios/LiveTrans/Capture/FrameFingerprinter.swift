import Foundation
import CoreGraphics
import ImageIO
import CoreMedia
import CoreVideo
import UIKit

enum FrameFingerprinter {
    static func fingerprint(cgImage: CGImage) -> String {
        let small = CGRect(x: 0, y: 0, width: 24, height: 24)
        guard let context = CGContext(
            data: nil,
            width: 24,
            height: 24,
            bitsPerComponent: 8,
            bytesPerRow: 24 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return "" }
        context.interpolationQuality = .none
        context.draw(cgImage, in: small)
        guard let data = context.data else { return "" }
        let bytes = UnsafeRawPointer(data).assumingMemoryBound(to: UInt8.self)
        return (0 ..< min(24 * 24 * 4, 512)).reduce(into: "") { result, i in
            result.append(String(format: "%02x", bytes[i]))
        }
        + "-\(cgImage.width)x\(cgImage.height)"
    }

    static func cgImage(from sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        guard let base = CVPixelBufferGetBaseAddress(imageBuffer) else { return nil }
        let data = Data(bytes: base, count: bytesPerRow * height)
        let provider = CGDataProvider(data: data as CFData)
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                .union(.byteOrder32Little),
            provider: provider!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}