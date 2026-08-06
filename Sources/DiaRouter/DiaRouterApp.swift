import AppKit
import SwiftUI

@main
struct DiaRouterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var coordinator = RouterCoordinator.shared

    private var menuBarSymbolName: String {
        if #available(macOS 15.0, *) {
            "arrow.trianglehead.swap"
        } else {
            "arrow.triangle.branch"
        }
    }

    var body: some Scene {
        MenuBarExtra("Dia Router", systemImage: menuBarSymbolName) {
            MenuBarContentView()
                .environmentObject(settings)
                .environmentObject(coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}
