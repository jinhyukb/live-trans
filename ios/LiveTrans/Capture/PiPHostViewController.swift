import UIKit
import AVFoundation
import AVKit

final class PiPHostViewController: UIViewController {
    let displayLayer = AVSampleBufferDisplayLayer()

    var pictureInPictureController: AVPictureInPictureController?
    var onChangeCaptionVisibility: (() -> Void)?
    var onTogglePlayback: ((Bool) -> Void)?
    var isPlaybackPaused: (() -> Bool)?

    override func viewDidLoad() {
        super.viewDidLoad()
        displayLayer.videoGravity = .resizeAspect
        displayLayer.frame = view.bounds
        displayLayer.backgroundColor = UIColor.black.cgColor
        view.layer.addSublayer(displayLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.frame = view.bounds
        CATransaction.commit()
    }

    func noteFormatDescription(_ formatDescription: CMFormatDescription) {
        guard pictureInPictureController == nil else { return }
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        guard let controller = AVPictureInPictureController(contentSource: contentSource) else { return }
        pictureInPictureController = controller
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        onChangeCaptionVisibility?()
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        if displayLayer.isReadyForMoreMediaData {
            displayLayer.enqueue(sampleBuffer)
        }
    }

    var captionVisibility: Bool {
        pictureInPictureController?.isPictureInPictureActive == true
    }
}

extension PiPHostViewController: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        setPlaying playing: Bool
    ) {
        onTogglePlayback?(playing)
    }

    func pictureInPictureControllerTimeRangeForPlayback(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> Bool {
        isPlaybackPaused?() ?? false
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {}

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completion completionHandler: @escaping @Sendable () -> Void
    ) {
        completionHandler()
    }
}