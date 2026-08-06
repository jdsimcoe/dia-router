import Foundation

struct DetectedDiaProfile: Equatable {
    let directory: String
    let name: String
}

enum DiaProfileState {
    private struct LocalState: Decodable {
        struct ProfileState: Decodable {
            struct ProfileInfo: Decodable {
                let activeTime: Double?
                let name: String

                enum CodingKeys: String, CodingKey {
                    case activeTime = "active_time"
                    case name
                }
            }

            let infoCache: [String: ProfileInfo]
            let lastUsed: String?

            enum CodingKeys: String, CodingKey {
                case infoCache = "info_cache"
                case lastUsed = "last_used"
            }
        }

        let profile: ProfileState
    }

    nonisolated static func currentProfileName() -> String? {
        guard let data = localStateData() else { return nil }
        return currentProfileName(from: data)
    }

    nonisolated static func currentProfileName(from data: Data) -> String? {
        guard let localState = try? JSONDecoder().decode(LocalState.self, from: data) else {
            return nil
        }

        if let lastUsed = localState.profile.lastUsed,
           let currentProfile = localState.profile.infoCache[lastUsed] {
            return currentProfile.name
        }

        return localState.profile.infoCache.values
            .max(by: { ($0.activeTime ?? 0) < ($1.activeTime ?? 0) })?
            .name
    }

    nonisolated static func detectedProfiles() -> [DetectedDiaProfile] {
        guard let data = localStateData() else { return [] }
        return detectedProfiles(from: data)
    }

    nonisolated static func detectedProfiles(from data: Data) -> [DetectedDiaProfile] {
        guard let localState = try? JSONDecoder().decode(LocalState.self, from: data) else {
            return []
        }

        return localState.profile.infoCache
            .map { DetectedDiaProfile(directory: $0.key, name: $0.value.name) }
            .sorted { lhs, rhs in
                let lhsIndex = profileIndex(for: lhs.directory)
                let rhsIndex = profileIndex(for: rhs.directory)
                if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
                return lhs.directory.localizedStandardCompare(rhs.directory) == .orderedAscending
            }
    }

    nonisolated static func otherProfile(
        than currentProfileName: String,
        in profiles: [DiaProfile]
    ) -> DiaProfile? {
        guard profiles.count > 1,
              let currentIndex = profiles.firstIndex(where: {
                  $0.name.compare(
                      currentProfileName,
                      options: [.caseInsensitive, .diacriticInsensitive]
                  ) == .orderedSame
              }) else {
            return nil
        }

        return profiles[(currentIndex + 1) % profiles.count]
    }

    private nonisolated static func localStateData() -> Data? {
        let localStateURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Dia/User Data/Local State")
        return try? Data(contentsOf: localStateURL)
    }

    private nonisolated static func profileIndex(for directory: String) -> Int {
        if directory == "Default" { return 0 }
        if directory.hasPrefix("Profile "),
           let number = Int(directory.dropFirst("Profile ".count)) {
            return number + 1
        }
        return .max
    }
}
