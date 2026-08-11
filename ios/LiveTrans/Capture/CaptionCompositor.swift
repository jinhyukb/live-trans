import Foundation
import UIKit
import CoreMedia
import CoreVideo

struct CaptionOverlay: Equatable {
    let line: String
    var frame: CGRect
}

final class CaptionCompositor: @unchecked Sendable {
    private var overlay: CaptionOverlay?
    private let queue = DispatchQueue(label: "live-trans.compositor")
    private let renderQueue = DispatchQueue(label: "live-trans.compositor.render")

    func update(line: String, in frame: CGRect) {
        queue.async { self.overlay = CaptionOverlay(line: line, frame: frame) }
    }

    func clear() {
        queue.async { self.overlay = nil }
    }

    func composite(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)

        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else {
            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
            return nil
        }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(imageBuffer)

        var copied: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            CVPixelBufferGetPixelFormatType(imageBuffer),
            nil,
            &copied
        )
        guard let copied, let copyBase = CVPixelBufferGetBaseAddress(copied) else {
            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
            return nil
        }
        memcpy(copyBase, baseAddress, rowBytes * height)
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)

        renderQueue.sync { [self] in
            guard let overlay else { return }
            CVPixelBufferLockBaseAddress(copied, [])
            defer { CVPixelBufferUnlockBaseAddress(copied, []) }
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(copied),
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(copied),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            )
            guard let context else { return }
            draw(overlay, in: context, width: width, height: height)
        }

        var formatDescriptionOut: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: copied,
            formatDescriptionOut: &formatDescriptionOut
        )
        guard formatStatus == noErr, let formatDescriptionOut else { return nil }

        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            decodeTimeStamp: .invalid
        )
        var newSample: CMSampleBuffer?
        let status = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: copied,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescriptionOut,
            sampleTiming: &timing,
            sampleBufferOut: &newSample
        )
        guard status == noErr, let newSample else { return nil }
        return newSample
    }

    private func draw(_ overlay: CaptionOverlay, in context: CGContext, width: Int, height: Int) {
        let rect = CGRect(
            x: overlay.frame.minX * CGFloat(width),
            y: overlay.frame.minY * CGFloat(height),
            width: overlay.frame.width * CGFloat(width),
            height: overlay.frame.height * CGFloat(height)
        )
        context.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
        context.fill(rect)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: rect.height * 0.7, weight: .semibold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph,
        ]
        let textRect = rect.insetBy(dx: 8, dy: 4)
        (overlay.line as NSString).draw(in: textRect, withAttributes: attributes)
    }
}