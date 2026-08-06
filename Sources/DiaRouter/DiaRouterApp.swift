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
            Text(coordinator.lastMessage)
                .foregroundStyle(.secondary)

            Divider()

            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
            }

            if DiaController.hasAccessibilityPermission {
                Label("Accessibility Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Request Accessibility Permission") {
                    DiaController.requestAccessibilityPermission()
                }
            }

            Divider()

            Button("Quit Dia Router") {
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(coordinator)
        }
    }
}
