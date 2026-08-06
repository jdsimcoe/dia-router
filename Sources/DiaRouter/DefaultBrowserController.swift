import AppKit
import Foundation

enum DefaultBrowserController {
    static var isDefaultRouter: Bool {
        guard let probeURL = URL(string: "https://example.com"),
              let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: probeURL),
              let bundle = Bundle(url: applicationURL) else {
            return false
        }

        return bundle.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    static func makeDefaultRouter() async throws {
        let applicationURL = Bundle.main.bundleURL
        try await setDefault(applicationURL: applicationURL, scheme: "http")
        try await setDefault(applicationURL: applicationURL, scheme: "https")
    }

    static func claimCustomScheme() async throws {
        try await setDefault(
            applicationURL: Bundle.main.bundleURL,
            scheme: "dia-router"
        )
    }

    private static func setDefault(applicationURL: URL, scheme: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.setDefaultApplication(
                at: applicationURL,
                toOpenURLsWithScheme: scheme
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
