import AppKit
import Darwin

var mainAppURL = Bundle.main.bundleURL
for _ in 0..<4 {
    mainAppURL.deleteLastPathComponent()
}

let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = false

NSWorkspace.shared.openApplication(
    at: mainAppURL,
    configuration: configuration
) { _, error in
    if let error {
        NSLog("Could not open Dia Router: %@", error.localizedDescription)
        exit(EXIT_FAILURE)
    }
    exit(EXIT_SUCCESS)
}

NSApplication.shared.run()
