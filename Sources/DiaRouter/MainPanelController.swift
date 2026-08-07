import AppKit
import SwiftUI

/// Resizable floating panel for rules + settings.
/// MenuBarExtra windows cannot be resized; this is the real host UI.
@MainActor
final class MainPanelController {
    static let shared = MainPanelController()

    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private let panelDelegate = PanelDismissDelegate()

    private init() {}

    func installStatusItem() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let symbolName: String
            if #available(macOS 15.0, *) {
                symbolName = "arrow.trianglehead.swap"
            } else {
                symbolName = "arrow.triangle.branch"
            }
            let image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: "Dia Router"
            )
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Dia Router"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        toggle()
    }

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    func show() {
        let panel = ensurePanel()
        positionIfNeeded(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func ensurePanel() -> NSPanel {
        if let panel {
            return panel
        }

        let rootView = MenuBarContentView()
            .environmentObject(SettingsStore.shared)
            .environmentObject(RouterCoordinator.shared)

        let hosting = NSHostingController(rootView: rootView)
        hosting.sizingOptions = [.minSize]

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 520),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Dia Router"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 420, height: 280)
        panel.contentViewController = hosting
        panel.setFrameAutosaveName("DiaRouterMainPanel")
        panel.delegate = panelDelegate

        self.panel = panel
        return panel
    }

    private func positionIfNeeded(_ panel: NSPanel) {
        // Autosave restores the last frame when available; only place near the
        // status item when the panel has never been positioned.
        let saved = panel.frameAutosaveName
        if !saved.isEmpty,
           UserDefaults.standard.string(forKey: "NSWindow Frame \(saved)") != nil {
            return
        }

        guard let button = statusItem?.button,
              let buttonWindow = button.window else {
            panel.center()
            return
        }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        var frame = panel.frame
        frame.origin.x = screenRect.midX - frame.width / 2
        frame.origin.y = screenRect.minY - frame.height - 8

        if let screen = buttonWindow.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            frame.origin.x = min(max(frame.origin.x, visible.minX + 8), visible.maxX - frame.width - 8)
            frame.origin.y = min(max(frame.origin.y, visible.minY + 8), visible.maxY - frame.height - 8)
        }

        panel.setFrame(frame, display: false)
    }
}

/// Keeps the panel from being released; status-item toggle owns visibility.
private final class PanelDismissDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
