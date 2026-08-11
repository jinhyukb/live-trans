import SwiftUI
import ReplayKit

struct BroadcastPicker: UIViewRepresentable {
    static let extensionBundleID = "com.livetrans.ios.BroadcastExtension"

    func makeUIView(context: Context) -> UIView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 90, height: 90))
        picker.preferredExtension = Self.extensionBundleID
        picker.showsMicrophoneButton = false
        picker.backgroundColor = .clear
        let wrapper = UIView(frame: picker.bounds)
        wrapper.addSubview(picker)
        return wrapper
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}