import Foundation
import Vision
import CoreGraphics
import LiveTransCore

struct OCRFrame: @unchecked Sendable {
    let cgImage: CGImage
    let fingerprint: String
}

struct VisionOCRService: Sendable {
    var embeddedAreaThreshold: Double = 0.04
    var embeddedBlockThreshold = 1

    func recognize(_ frame: OCRFrame) async throws -> [ScreenTextBlock] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "ja-JP", "ko-KR"]

        let handler = VNImageRequestHandler(cgImage: frame.cgImage)
        try handler.perform([request])

        let blocks = (request.results ?? []).map { observation in
            let text = observation.topCandidates(1).first?.string ?? ""
            let box = observation.boundingBox
            return ScreenTextBlock(
                text: text,
                rect: NormalizedRect(
                    x: Double(box.minX),
                    y: Double(1 - box.maxY),
                    width: Double(box.width),
                    height: Double(box.height)
                ),
                kind: kind(for: box)
            )
        }
        return blocks
    }

    private func kind(for box: CGRect) -> ScreenTextKind {
        let area = Double(box.width * box.height)
        return area >= embeddedAreaThreshold ? .embedded : .onScreen
    }
}