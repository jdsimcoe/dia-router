import Foundation
import Testing
@testable import DiaRouter

struct RuleMatcherTests {
    private let workID = RouterConfiguration.workProfileID
    private let personalID = RouterConfiguration.personalProfileID

    @Test
    func domainRuleMatchesDomainAndSubdomains() throws {
        let rule = RoutingRule(
            id: UUID(),
            isEnabled: true,
            matchType: .domain,
            pattern: "slack.com",
            profileID: workID
        )

        #expect(RuleMatcher.matches(rule, url: try #require(URL(string: "https://slack.com"))))
        #expect(RuleMatcher.matches(rule, url: try #require(URL(string: "https://app.slack.com/client"))))
        #expect(!RuleMatcher.matches(rule, url: try #require(URL(string: "https://fakeslack.com"))))
    }

    @Test
    func urlContainsRuleIsCaseInsensitive() throws {
        let rule = RoutingRule(
            id: UUID(),
            isEnabled: true,
            matchType: .urlContains,
            pattern: "AUTHUSER=WORK",
            profileID: workID
        )

        #expect(RuleMatcher.matches(
            rule,
            url: try #require(URL(string: "https://docs.google.com/document/1?authuser=work"))
        ))
    }

    @Test
    func firstRuleWinsAndDefaultHandlesUnmatchedURLs() throws {
        let configuration = RouterConfiguration(
            profiles: [
                DiaProfile(id: workID, name: "Work", shortcutNumber: 1),
                DiaProfile(id: personalID, name: "Personal", shortcutNumber: 2),
            ],
            rules: [
                RoutingRule(
                    id: UUID(),
                    isEnabled: true,
                    matchType: .domain,
                    pattern: "linear.app",
                    profileID: workID
                ),
            ],
            defaultProfileID: personalID
        )

        let workURL = try #require(URL(string: "https://linear.app/acme/issue/ABC-123"))
        let personalURL = try #require(URL(string: "https://example.com"))

        #expect(RuleMatcher.profile(for: workURL, configuration: configuration)?.id == workID)
        #expect(RuleMatcher.profile(for: personalURL, configuration: configuration)?.id == personalID)
    }

    @Test
    func customURLCanForceANamedProfile() throws {
        let incomingURL = try #require(URL(
            string: "dia-router://open?url=https%3A%2F%2Fyoutu.be%2Fabc123&profile=Personal"
        ))
        let request = try #require(RouterCoordinator.parse(incomingURL))

        #expect(request.url.absoluteString == "https://youtu.be/abc123")
        #expect(request.forcedProfileName == "Personal")
    }

    @Test
    func currentProfileUsesDiasExplicitLastUsedProfile() throws {
        let localState = Data(#"""
        {
          "profile": {
            "last_used": "Default",
            "info_cache": {
              "Default": { "active_time": 100, "name": "Work" },
              "Profile 1": { "active_time": 200, "name": "Personal" }
            }
          }
        }
        """#.utf8)

        #expect(DiaProfileState.currentProfileName(from: localState) == "Work")
    }

    @Test
    func currentProfileFallsBackToMostRecentActivity() throws {
        let localState = Data(#"""
        {
          "profile": {
            "info_cache": {
              "Default": { "active_time": 100, "name": "Work" },
              "Profile 1": { "active_time": 200, "name": "Personal" }
            }
          }
        }
        """#.utf8)

        #expect(DiaProfileState.currentProfileName(from: localState) == "Personal")
    }

    @Test
    func detectedProfilesUseDiasDirectoryOrder() {
        let localState = Data(#"""
        {
          "profile": {
            "info_cache": {
              "Profile 2": { "name": "Research" },
              "Default": { "name": "Work" },
              "Profile 1": { "name": "Personal" }
            }
          }
        }
        """#.utf8)

        #expect(DiaProfileState.detectedProfiles(from: localState) == [
            DetectedDiaProfile(directory: "Default", name: "Work"),
            DetectedDiaProfile(directory: "Profile 1", name: "Personal"),
            DetectedDiaProfile(directory: "Profile 2", name: "Research"),
        ])
    }

    @Test
    func otherProfileWrapsBetweenConfiguredProfiles() throws {
        let profiles = [
            DiaProfile(id: workID, name: "Work", shortcutNumber: 1),
            DiaProfile(id: personalID, name: "Personal", shortcutNumber: 2),
        ]

        #expect(DiaProfileState.otherProfile(than: "Work", in: profiles)?.name == "Personal")
        #expect(DiaProfileState.otherProfile(than: "personal", in: profiles)?.name == "Work")
    }

    @Test
    func syncingProfilesAddsDetectedProfilesAndAssignsShortcuts() throws {
        var configuration = RouterConfiguration.defaultConfiguration
        configuration.syncProfiles(with: [
            DetectedDiaProfile(directory: "Default", name: "Work"),
            DetectedDiaProfile(directory: "Profile 1", name: "Personal"),
            DetectedDiaProfile(directory: "Profile 2", name: "Research"),
        ])
        let profile = try #require(configuration.profiles.last)

        #expect(profile.name == "Research")
        #expect(profile.shortcutNumber == 3)
        #expect(profile.diaDirectory == "Profile 2")
        #expect(configuration.profiles.count == 3)
    }

    @Test
    func syncingProfilesPreservesRulesAcrossDiaRenames() throws {
        var configuration = RouterConfiguration.defaultConfiguration
        configuration.syncProfiles(with: [
            DetectedDiaProfile(directory: "Default", name: "Work"),
            DetectedDiaProfile(directory: "Profile 1", name: "Personal"),
        ])
        let workID = configuration.profiles[0].id

        configuration.syncProfiles(with: [
            DetectedDiaProfile(directory: "Default", name: "Mercury"),
            DetectedDiaProfile(directory: "Profile 1", name: "Personal"),
        ])

        #expect(configuration.profiles.count == 2)
        #expect(configuration.profiles[0].id == workID)
        #expect(configuration.profiles[0].name == "Mercury")
        #expect(configuration.rules.first?.profileID == workID)
    }

    @Test
    func syncingProfilesPreservesShortcutOverrides() {
        var configuration = RouterConfiguration.defaultConfiguration
        configuration.syncProfiles(with: [
            DetectedDiaProfile(directory: "Default", name: "Work"),
            DetectedDiaProfile(directory: "Profile 1", name: "Personal"),
        ])
        configuration.profiles[0].shortcutNumber = 4

        configuration.syncProfiles(with: [
            DetectedDiaProfile(directory: "Default", name: "Work"),
            DetectedDiaProfile(directory: "Profile 1", name: "Personal"),
        ])

        #expect(configuration.profiles[0].shortcutNumber == 4)
        #expect(configuration.profiles[1].shortcutNumber == 2)
    }
}
