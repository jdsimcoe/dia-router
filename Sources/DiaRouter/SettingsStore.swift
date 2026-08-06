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

    @discardableResult
    func addRule() -> UUID? {
        guard let targetProfile = configuration.profiles.first(where: {
            $0.id == configuration.defaultProfileID
        }) ?? configuration.profiles.first else { return nil }

        let rule = RoutingRule(
            id: UUID(),
            isEnabled: true,
            matchType: .domain,
            pattern: "",
            profileID: targetProfile.id
        )
        configuration.rules.append(rule)
        return rule.id
    }

    func deleteRule(id: UUID) {
        configuration.rules.removeAll { $0.id == id }
    }

    func moveRule(id: UUID, by offset: Int) {
        guard let sourceIndex = configuration.rules.firstIndex(where: { $0.id == id }) else {
            return
        }

        let destinationIndex = sourceIndex + offset
        guard configuration.rules.indices.contains(destinationIndex) else { return }
        configuration.rules.swapAt(sourceIndex, destinationIndex)
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
