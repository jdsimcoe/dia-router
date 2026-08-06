import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerToOpenAtLogin()

        Task {
            try? await DefaultBrowserController.claimCustomScheme()
        }
    }

    private func registerToOpenAtLogin() {
        let service = SMAppService.loginItem(
            identifier: "com.diarouter.DiaRouter.LoginItem"
        )

        let migrationKey = "renamedLoginItemToDiaRouter.v1"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            do {
                try service.unregister()
            } catch {
                NSLog("Could not unregister the previous Dia Router login item: %@", error.localizedDescription)
            }
            UserDefaults.standard.set(true, forKey: migrationKey)
        }

        guard service.status != .enabled,
              service.status != .requiresApproval else {
            return
        }

        do {
            try service.register()
        } catch {
            NSLog("Could not register Dia Router to open at login: %@", error.localizedDescription)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { @MainActor in
                RouterCoordinator.shared.route(url)
            }
        }
    }
}
