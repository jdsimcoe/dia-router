import Foundation

struct DiaProfile: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var shortcutNumber: Int
    var diaDirectory: String? = nil
}

enum RuleMatchType: String, Codable, CaseIterable, Identifiable {
    case domain
    case urlContains
    case regularExpression

    var id: String { rawValue }

    var label: String {
        switch self {
        case .domain:
            "Domain"
        case .urlContains:
            "URL contains"
        case .regularExpression:
            "Regular expression"
        }
    }
}

struct RoutingRule: Codable, Hashable, Identifiable {
    var id: UUID
    var isEnabled: Bool
    var matchType: RuleMatchType
    var pattern: String
    var profileID: UUID
}

struct RouterConfiguration: Codable, Equatable {
    var profiles: [DiaProfile]
    var rules: [RoutingRule]
    var defaultProfileID: UUID

    static let workProfileID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let personalProfileID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    static let defaultConfiguration = RouterConfiguration(
        profiles: [
            DiaProfile(id: workProfileID, name: "Work", shortcutNumber: 1),
            DiaProfile(id: personalProfileID, name: "Personal", shortcutNumber: 2),
        ],
        rules: [
            RoutingRule(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                isEnabled: true,
                matchType: .domain,
                pattern: "slack.com",
                profileID: workProfileID
            ),
            RoutingRule(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                isEnabled: true,
                matchType: .domain,
                pattern: "linear.app",
                profileID: workProfileID
            ),
            RoutingRule(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                isEnabled: true,
                matchType: .domain,
                pattern: "notion.so",
                profileID: workProfileID
            ),
            RoutingRule(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
                isEnabled: true,
                matchType: .domain,
                pattern: "notion.com",
                profileID: workProfileID
            ),
            RoutingRule(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
                isEnabled: true,
                matchType: .domain,
                pattern: "meet.google.com",
                profileID: workProfileID
            ),
        ],
        defaultProfileID: personalProfileID
    )

    mutating func syncProfiles(with detectedProfiles: [DetectedDiaProfile]) {
        let detectedProfiles = Array(detectedProfiles.prefix(9))
        guard !detectedProfiles.isEmpty else { return }

        let previousProfiles = profiles
        var matchedProfileIDs = Set<UUID>()
        var syncedProfiles: [DiaProfile] = []

        for (index, detectedProfile) in detectedProfiles.enumerated() {
            let matchingProfile = previousProfiles.first { profile in
                guard !matchedProfileIDs.contains(profile.id) else { return false }

                if let diaDirectory = profile.diaDirectory {
                    return diaDirectory == detectedProfile.directory
                }

                return profile.name.compare(
                    detectedProfile.name,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) == .orderedSame
            }

            var profile = matchingProfile ?? DiaProfile(
                id: UUID(),
                name: detectedProfile.name,
                shortcutNumber: index + 1
            )
            profile.name = detectedProfile.name
            profile.diaDirectory = detectedProfile.directory
            matchedProfileIDs.insert(profile.id)
            syncedProfiles.append(profile)
        }

        profiles = syncedProfiles

        if !profiles.contains(where: { $0.id == defaultProfileID }) {
            defaultProfileID = profiles[0].id
        }

        for ruleIndex in rules.indices
        where !profiles.contains(where: { $0.id == rules[ruleIndex].profileID }) {
            rules[ruleIndex].profileID = defaultProfileID
        }
    }
}
