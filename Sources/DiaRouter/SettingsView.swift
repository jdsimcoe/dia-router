import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var coordinator: RouterCoordinator

    @State private var testURLString = "https://linear.app"
    @State private var isDefaultRouter = false
    @State private var isMakingDefault = false

    var body: some View {
        VStack(spacing: 0) {
            defaultBrowserBanner

            Form {
                statusSection
                profilesSection
                rulesSection
                testSection
            }
            .formStyle(.grouped)
        }
        .frame(width: 720, height: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            refreshDefaultBrowserStatus()
            settings.syncProfilesFromDia()
        }
    }

    private var defaultBrowserBanner: some View {
        HStack(spacing: 16) {
            Text(
                isDefaultRouter
                    ? "Dia Router is your default browser"
                    : "Dia Router works best as your default browser"
            )
            .font(.body)

            Spacer()

            if isDefaultRouter {
                Label("Default", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Set Dia Router as Default") {
                    makeDefaultRouter()
                }
                .buttonStyle(.bordered)
                .disabled(isMakingDefault)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    private var statusSection: some View {
        Section("Status") {
            LabeledContent("Accessibility") {
                HStack {
                    Text(DiaController.hasAccessibilityPermission ? "Allowed" : "Required")
                        .foregroundStyle(DiaController.hasAccessibilityPermission ? .green : .orange)
                    if !DiaController.hasAccessibilityPermission {
                        Button("Request Permission") {
                            DiaController.requestAccessibilityPermission()
                        }
                    }
                }
            }

            LabeledContent("Last action") {
                Text(coordinator.lastMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var profilesSection: some View {
        Section {
            ForEach($settings.configuration.profiles) { $profile in
                LabeledContent("Profile name") {
                    HStack(spacing: 12) {
                        Text(profile.name)
                            .frame(width: 110)
                            .multilineTextAlignment(.trailing)

                        Text("Dia shortcut:")
                            .foregroundStyle(.secondary)

                        Picker(
                            "Dia shortcut",
                            selection: $profile.shortcutNumber
                        ) {
                            ForEach(1...9, id: \.self) { number in
                                Text("⌘⌥\(number)")
                                    .tag(number)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)
                    }
                    .padding(.trailing, 12)
                }
            }

            LabeledContent("Default profile") {
                Picker("Default profile", selection: $settings.configuration.defaultProfileID) {
                    ForEach(settings.configuration.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .labelsHidden()
                .frame(width: 140, alignment: .trailing)
                .padding(.trailing, 12)
            }

            HStack {
                Label(
                    settings.diaProfilesDetected
                        ? "Profiles detected from Dia"
                        : "Could not detect Dia profiles",
                    systemImage: settings.diaProfilesDetected
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(settings.diaProfilesDetected ? .green : .orange)

                Spacer()

                Text("\(settings.configuration.profiles.count) profiles")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Dia Profiles")
        } footer: {
            Text("Profiles are detected from Dia and mapped in order to ⌘⌥1, ⌘⌥2, and so on. Configure the same shortcuts in Dia → Settings → Shortcuts. Current mapping: \(profileMappingDescription).")
        }
    }

    private var profileMappingDescription: String {
        settings.configuration.profiles
            .map { "\($0.name) = ⌘⌥\($0.shortcutNumber)" }
            .joined(separator: ", ")
    }

    private var rulesSection: some View {
        Section {
            ForEach($settings.configuration.rules) { $rule in
                RuleRow(rule: $rule, profiles: settings.configuration.profiles)
            }
            .onDelete(perform: settings.deleteRules)

            HStack {
                Button("Add Rule") {
                    settings.addRule()
                }
                Spacer()
                Button("Reset Defaults", role: .destructive) {
                    settings.resetToDefaults()
                }
            }
        } header: {
            Text("Routing Rules")
        } footer: {
            Text("Rules are evaluated from top to bottom. The first match wins; unmatched URLs use the default profile.")
        }
    }

    private var testSection: some View {
        Section {
            LabeledContent("URL") {
                HStack(spacing: 12) {
                    TextField("https://linear.app", text: $testURLString)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 260)

                    Text("→ \(matchedTestProfileName)")
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    Button("Open in \(matchedTestProfileName)") {
                        if let url = normalizedTestURL {
                            coordinator.route(url)
                        }
                    }
                    .disabled(normalizedTestURL == nil || coordinator.isRouting)
                }
            }
        } header: {
            Text("Test Routing")
        } footer: {
            Text("Linear is the default example because it matches the built-in Work rule. Edit the URL to preview any rule or fallback.")
        }
    }

    private var normalizedTestURL: URL? {
        if let directURL = URL(string: testURLString), directURL.scheme != nil {
            return directURL
        }
        return URL(string: "https://\(testURLString)")
    }

    private var matchedTestProfileName: String {
        guard let url = normalizedTestURL else { return "Invalid URL" }
        return settings.profile(for: url)?.name ?? "No profile"
    }

    private func refreshDefaultBrowserStatus() {
        isDefaultRouter = DefaultBrowserController.isDefaultRouter
    }

    private func makeDefaultRouter() {
        isMakingDefault = true
        Task {
            do {
                try await DefaultBrowserController.makeDefaultRouter()
                isDefaultRouter = true
                coordinator.lastMessage = "Dia Router is now the default web router"
            } catch {
                coordinator.lastMessage = error.localizedDescription
                refreshDefaultBrowserStatus()
            }
            isMakingDefault = false
        }
    }
}

private struct RuleRow: View {
    @Binding var rule: RoutingRule
    let profiles: [DiaProfile]

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $rule.isEnabled)
                .labelsHidden()

            Picker("", selection: $rule.matchType) {
                ForEach(RuleMatchType.allCases) { matchType in
                    Text(matchType.label).tag(matchType)
                }
            }
            .labelsHidden()
            .frame(width: 150)

            TextField("Pattern", text: $rule.pattern)
                .textFieldStyle(.roundedBorder)

            Image(systemName: "arrow.right")
                .foregroundStyle(.tertiary)

            Picker("", selection: $rule.profileID) {
                ForEach(profiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }
            .labelsHidden()
            .frame(width: 120)
        }
    }
}
