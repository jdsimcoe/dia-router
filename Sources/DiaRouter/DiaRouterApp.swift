import AppKit
import SwiftUI

@main
struct DiaRouterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Status item + resizable panel are owned by AppDelegate / MainPanelController.
        // Settings is only present because SwiftUI App requires at least one Scene.
        Settings {
            EmptyView()
        }
    }
}
