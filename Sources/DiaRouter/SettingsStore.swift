import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private static let configurationKey = "routerConfiguration.v1"

    @Published var configuration: RouterConfiguration {
        didSet { save() }
    }

    @Published private(set) var diaProfilesDetected = false

    private init(defaults: UserDefaults = .standard) {
        var loadedConfiguration: RouterConfiguration
        if let data = defaults.data(forKey: Self.configurationKey),
           let decoded = try? JSONDecoder().decode(RouterConfiguration.self, from: data) {
            loadedConfiguration = decoded
        } else {
            loadedConfiguration = .defaultConfiguration
        }

        let detectedProfiles = DiaProfileState.detectedProfiles()
        if !detectedProfiles.isEmpty {
            loadedConfiguration.syncProfiles(with: detectedProfiles)
            diaProfilesDetected = true
        }
        configuration = loadedConfiguration

        if let data = try? JSONEncoder().encode(configuration) {
            defaults.set(data, forKey: Self.configurationKey)
        }
    }

    func profile(for url: URL) -> DiaProfile? {
        RuleMatcher.profile(for: url, configuration: configuration)
    }

    func addRule() {
        guard let targetProfile = configuration.profiles.first else { return }
        configuration.rules.append(
            RoutingRule(
                id: UUID(),
                isEnabled: true,
                matchType: .domain,
                pattern: "example.com",
                profileID: targetProfile.id
            )
        )
    }

    @discardableResult
    func syncProfilesFromDia() -> Bool {
        let detectedProfiles = DiaProfileState.detectedProfiles()
        guard !detectedProfiles.isEmpty else {
            diaProfilesDetected = false
            return false
        }

        var updatedConfiguration = configuration
        updatedConfiguration.syncProfiles(with: detectedProfiles)
        if updatedConfiguration != configuration {
            configuration = updatedConfiguration
        }
        diaProfilesDetected = true
        return true
    }

    func deleteRules(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            configuration.rules.remove(at: index)
        }
    }

    func resetToDefaults() {
        var defaultConfiguration = RouterConfiguration.defaultConfiguration
        defaultConfiguration.syncProfiles(with: DiaProfileState.detectedProfiles())
        configuration = defaultConfiguration
    }

    private func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: Self.configurationKey)
    }
}
