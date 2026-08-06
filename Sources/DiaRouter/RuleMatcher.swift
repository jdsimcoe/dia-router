import Foundation

enum RuleMatcher {
    static func matches(_ rule: RoutingRule, url: URL) -> Bool {
        guard rule.isEnabled else { return false }

        let trimmedPattern = rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPattern.isEmpty else { return false }

        switch rule.matchType {
        case .domain:
            guard let host = url.host?.lowercased() else { return false }
            let domain = trimmedPattern
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return host == domain || host.hasSuffix(".\(domain)")

        case .urlContains:
            return url.absoluteString.range(
                of: trimmedPattern,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil

        case .regularExpression:
            return url.absoluteString.range(
                of: trimmedPattern,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
    }

    static func profile(
        for url: URL,
        configuration: RouterConfiguration
    ) -> DiaProfile? {
        if let matchedRule = configuration.rules.first(where: { matches($0, url: url) }),
           let matchedProfile = configuration.profiles.first(where: { $0.id == matchedRule.profileID }) {
            return matchedProfile
        }

        return configuration.profiles.first(where: { $0.id == configuration.defaultProfileID })
            ?? configuration.profiles.first
    }
}
