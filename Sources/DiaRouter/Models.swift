import Foundation

struct DiaProfile: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var shortcutNumber: Int
    var diaDirectory: String? = nil
    var lastDetectedName: String? = nil
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

/// The modifier keys Dia Router holds down with a profile number. Dia lets you
/// choose the modifiers for its own profile-switching shortcuts, so Router has
/// to send whichever combination Dia listens for.
enum ProfileShortcutModifier: String, Codable, CaseIterable, Identifiable {
    case commandOption
    case control
    case controlOption
    case controlCommand
    case commandShift

    var id: String { rawValue }

    /// Modifier symbols in the order macOS uses: control, option, shift, command.
    var symbols: String {
        switch self {
        case .commandOption:
            "⌥⌘"
        case .control:
            "⌃"
        case .controlOption:
            "⌃⌥"
        case .controlCommand:
            "⌃⌘"
        case .commandShift:
            "⇧⌘"
        }
    }

    func label(for number: Int) -> String {
        "\(symbols)\(number)"
    }
}

struct RouterConfiguration: Codable, Equatable {
    var profiles: [DiaProfile]
    var rules: [RoutingRule]
    var defaultProfileID: UUID
    var shortcutModifier: ProfileShortcutModifier = .commandOption

    // A configuration saved before the modifier was configurable has no
    // shortcutModifier key, and one saved by a later version may name a
    // modifier this version does not know. Fall back to the previous fixed
    // combination in both cases rather than failing to decode, which would
    // discard every saved profile and rule.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try container.decode([DiaProfile].self, forKey: .profiles)
        rules = try container.decode([RoutingRule].self, forKey: .rules)
        defaultProfileID = try container.decode(UUID.self, forKey: .defaultProfileID)
        shortcutModifier = try container
            .decodeIfPresent(String.self, forKey: .shortcutModifier)
            .flatMap(ProfileShortcutModifier.init(rawValue:)) ?? .commandOption
    }

    init(
        profiles: [DiaProfile],
        rules: [RoutingRule],
        defaultProfileID: UUID,
        shortcutModifier: ProfileShortcutModifier = .commandOption
    ) {
        self.profiles = profiles
        self.rules = rules
        self.defaultProfileID = defaultProfileID
        self.shortcutModifier = shortcutModifier
    }

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
                shortcutNumber: index + 1,
                lastDetectedName: detectedProfile.name
            )

            let followsDetectedName = profile.lastDetectedName == nil ||
                profile.name.compare(
                    profile.lastDetectedName ?? "",
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) == .orderedSame
            let alreadyMatchesDetection = profile.name.compare(
                detectedProfile.name,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame

            if followsDetectedName || alreadyMatchesDetection {
                profile.name = detectedProfile.name
            }
            profile.diaDirectory = detectedProfile.directory
            profile.lastDetectedName = detectedProfile.name
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
