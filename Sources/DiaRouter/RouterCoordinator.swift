import Foundation

@MainActor
final class RouterCoordinator: ObservableObject {
    static let shared = RouterCoordinator()

    @Published private(set) var isRouting = false
    @Published var lastMessage = "Ready"

    private var pendingRoutes: [(url: URL, profile: DiaProfile)] = []

    private init() {}

    func route(_ incomingURL: URL) {
        guard let request = Self.parse(incomingURL) else {
            lastMessage = "Ignored unsupported URL"
            return
        }

        SettingsStore.shared.syncProfilesFromDia()

        let profile: DiaProfile?
        if request.forcedProfileName?.compare("Other", options: .caseInsensitive) == .orderedSame,
           let currentProfileName = DiaProfileState.currentProfileName() {
            profile = DiaProfileState.otherProfile(
                than: currentProfileName,
                in: SettingsStore.shared.configuration.profiles
            )
        } else if let forcedProfileName = request.forcedProfileName {
            profile = SettingsStore.shared.configuration.profiles.first {
                $0.name.compare(forcedProfileName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
        } else {
            profile = SettingsStore.shared.profile(for: request.url)
        }

        guard let profile else {
            if request.forcedProfileName?.compare("Other", options: .caseInsensitive) == .orderedSame {
                lastMessage = "Could not determine the other Dia profile"
            } else if let forcedProfileName = request.forcedProfileName {
                lastMessage = "Dia profile “\(forcedProfileName)” was not found"
            } else {
                lastMessage = "No Dia profile is configured"
            }
            return
        }

        pendingRoutes.append((request.url, profile))
        processNextRouteIfNeeded()
    }

    private func processNextRouteIfNeeded() {
        guard !isRouting, !pendingRoutes.isEmpty else { return }

        let nextRoute = pendingRoutes.removeFirst()
        isRouting = true
        lastMessage = "Opening \(nextRoute.url.host ?? nextRoute.url.absoluteString) in \(nextRoute.profile.name)…"

        Task {
            do {
                try await DiaController.route(nextRoute.url, to: nextRoute.profile)
                lastMessage = "Opened in \(nextRoute.profile.name)"
            } catch {
                lastMessage = error.localizedDescription
            }
            isRouting = false
            processNextRouteIfNeeded()
        }
    }

    struct RouteRequest: Equatable {
        let url: URL
        let forcedProfileName: String?
    }

    nonisolated static func parse(_ incomingURL: URL) -> RouteRequest? {
        if ["http", "https"].contains(incomingURL.scheme?.lowercased() ?? "") {
            return RouteRequest(url: incomingURL, forcedProfileName: nil)
        }

        if incomingURL.scheme?.lowercased() == "dia-router",
           let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: false),
           let value = components.queryItems?.first(where: { $0.name == "url" })?.value,
           let url = URL(string: value) {
            let profileName = components.queryItems?
                .first(where: { $0.name == "profile" })?
                .value?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return RouteRequest(
                url: url,
                forcedProfileName: profileName?.isEmpty == false ? profileName : nil
            )
        }

        return nil
    }

    nonisolated static func unwrap(_ incomingURL: URL) -> URL? {
        parse(incomingURL)?.url
    }
}
