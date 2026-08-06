import AppKit
import ApplicationServices
import Foundation

enum DiaControllerError: LocalizedError {
    case diaNotInstalled
    case accessibilityPermissionMissing
    case invalidShortcutNumber(Int)
    case couldNotCreateKeyboardEvent

    var errorDescription: String? {
        switch self {
        case .diaNotInstalled:
            "Dia is not installed in /Applications."
        case .accessibilityPermissionMissing:
            "Dia Router needs Accessibility permission to switch Dia profiles."
        case let .invalidShortcutNumber(number):
            "Dia profile shortcut \(number) is not supported. Choose a number from 1 through 9."
        case .couldNotCreateKeyboardEvent:
            "Dia Router could not create the profile-switch keyboard event."
        }
    }
}

enum DiaController {
    static let diaBundleIdentifier = "company.thebrowser.dia"

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibilityPermission() -> Bool {
        let promptKey = "AXTrustedCheckOptionPrompt"
        return AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        // Register the currently running, signed app with TCC before opening
        // System Settings. Opening the pane alone can leave users toggling a
        // stale entry from an older bundle or signing identity.
        requestAccessibilityPermission()

        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    static func route(_ url: URL, to profile: DiaProfile) async throws {
        guard let diaURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: diaBundleIdentifier
        ) else {
            throw DiaControllerError.diaNotInstalled
        }

        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            throw DiaControllerError.accessibilityPermissionMissing
        }

        let runningDia = NSRunningApplication.runningApplications(
            withBundleIdentifier: diaBundleIdentifier
        ).first

        let diaApplication: NSRunningApplication
        if let runningDia {
            diaApplication = runningDia
            runningDia.activate(options: [.activateAllWindows])
        } else {
            diaApplication = try await launchDia(at: diaURL)
        }

        try await Task.sleep(for: .milliseconds(180))
        try sendProfileShortcut(profile.shortcutNumber, to: diaApplication.processIdentifier)
        try await Task.sleep(for: .milliseconds(260))
        try await open(url, inDiaAt: diaURL)
    }

    private static func launchDia(at applicationURL: URL) async throws -> NSRunningApplication {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        return try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.openApplication(
                at: applicationURL,
                configuration: configuration
            ) { application, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let application {
                    continuation.resume(returning: application)
                } else {
                    continuation.resume(throwing: DiaControllerError.diaNotInstalled)
                }
            }
        }
    }

    private static func open(_ url: URL, inDiaAt applicationURL: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: applicationURL,
                configuration: configuration
            ) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func sendProfileShortcut(_ number: Int, to processID: pid_t) throws {
        let keyCodes: [Int: CGKeyCode] = [
            1: 18,
            2: 19,
            3: 20,
            4: 21,
            5: 23,
            6: 22,
            7: 26,
            8: 28,
            9: 25,
        ]

        guard let keyCode = keyCodes[number] else {
            throw DiaControllerError.invalidShortcutNumber(number)
        }

        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: true
        ), let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: false
        ) else {
            throw DiaControllerError.couldNotCreateKeyboardEvent
        }

        keyDown.flags = [.maskCommand, .maskAlternate]
        keyUp.flags = [.maskCommand, .maskAlternate]
        keyDown.postToPid(processID)
        keyUp.postToPid(processID)
    }
}
