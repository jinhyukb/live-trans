import SwiftUI
import LiveTransCore

struct RootView: View {
    @EnvironmentObject private var model: LiveTransModel
    @State private var pipHost = PiPHostViewController()

    var body: some View {
        Group {
            if model.onboardingState != .completed {
                OnboardingView()
            } else {
                SessionToggleView()
            }
        }
        .background(
            PiPHostView(controller: pipHost)
                .frame(width: 0, height: 0)
                .onAppear {
                    model.setPiPHost(pipHost)
                }
        )
    }
}

private struct PiPHostView: UIViewControllerRepresentable {
    let controller: PiPHostViewController

    func makeUIViewController(context: Context) -> PiPHostViewController {
        controller
    }

    func updateUIViewController(_ uiViewController: PiPHostViewController, context: Context) {}
}