import SwiftUI
import ReplayKit

@main
struct LiveTransApp: App {
    @StateObject private var model = LiveTransModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}