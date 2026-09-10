import AppKit
import SwiftUI

private enum RuleEditorFocus: Hashable {
    case pattern(UUID)
    case profile(UUID)
    case enabled(UUID)
}

struct MenuBarContentView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var coordinator: RouterCoordinator

    @State private var page: Page = .rules
    @State private var hasAccessibilityPermission = DiaController.hasAccessibilityPermission
    @FocusState private var focusedField: RuleEditorFocus?

    private enum Page {
        case rules
        case settings
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            Group {
                switch page {
                case .rules:
                    RulesMenuView(
                        hasAccessibilityPermission: hasAccessibilityPermission,
                        focusedField: $focusedField
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))

                case .settings:
                    MenuBarSettingsView(
                        hasAccessibilityPermission: hasAccessibilityPermission
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .frame(width: 500)
        .background(.ultraThinMaterial)
        .onAppear {
            settings.syncProfilesFromDia()
            refreshAccessibilityPermission()
        }
        .task {
            while !Task.isCancelled {
                refreshAccessibilityPermission()
                try? await Task.sleep(for: .milliseconds(750))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Dia Router")
                .font(.body.weight(.semibold))

            if page == .settings {
                Text("Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if coordinator.isRouting {
                Text(coordinator.lastMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if page == .rules {
                headerButton("Settings", systemImage: "gearshape", action: showSettings)
            }

            headerButton("Quit Dia Router", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }

            switch page {
            case .rules:
                headerButton(
                    "Add Rule",
                    systemImage: "plus",
                    isContained: true,
                    action: addRule
                )
            case .settings:
                headerButton(
                    "Back to Rules",
                    systemImage: "chevron.left",
                    isContained: true,
                    action: showRules
                )
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
    }

    private func showSettings() {
        focusedField = nil
        withAnimation(.easeInOut(duration: 0.16)) {
            page = .settings
        }
    }

    private func showRules() {
        withAnimation(.easeInOut(duration: 0.16)) {
            page = .rules
        }
    }

    private func addRule() {
        guard let ruleID = settings.addRule() else { return }
        DispatchQueue.main.async {
            focusedField = .pattern(ruleID)
        }
    }

    private func headerButton(
        _ help: String,
        systemImage: String,
        isContained: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(isContained ? Color.primary : Color.secondary)
                .frame(width: 28, height: 28)
                .background {
                    if isContained {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.1))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(help)
        .help(help)
    }

    private func refreshAccessibilityPermission() {
        hasAccessibilityPermission = DiaController.hasAccessibilityPermission
    }
}

private struct RulesMenuView: View {
    @EnvironmentObject private var settings: SettingsStore

    let hasAccessibilityPermission: Bool
    @FocusState.Binding var focusedField: RuleEditorFocus?

    var body: some View {
        VStack(spacing: 0) {
            if !hasAccessibilityPermission {
                accessibilityBanner
                Divider()
            }

            rulesList
        }
    }

    private var accessibilityBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "accessibility")
                .foregroundStyle(.orange)
            Text("Accessibility permission is required for profile switching")
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button("Open System Settings…") {
                DiaController.openAccessibilitySettings()
            }
            .buttonStyle(.link)
        }
        .font(.caption)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var rulesList: some View {
        if settings.configuration.rules.isEmpty {
            ContentUnavailableView(
                "No routing rules",
                systemImage: "arrow.triangle.branch",
                description: Text("Unmatched links use the default profile.")
            )
            .frame(height: 150)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach($settings.configuration.rules) { $rule in
                            VStack(spacing: 0) {
                                MenuBarRuleRow(
                                    rule: $rule,
                                    profiles: settings.configuration.profiles,
                                    canMoveUp: rule.id != settings.configuration.rules.first?.id,
                                    canMoveDown: rule.id != settings.configuration.rules.last?.id,
                                    focusedField: $focusedField,
                                    move: { offset in
                                        settings.moveRule(id: rule.id, by: offset)
                                    },
                                    delete: {
                                        settings.deleteRule(id: rule.id)
                                    }
                                )

                                if rule.id != settings.configuration.rules.last?.id {
                                    Divider()
                                        .padding(.leading, 38)
                                }
                            }
                            .id(rule.id)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: rulesListHeight)
                .onChange(of: focusedField) { _, focus in
                    guard case let .pattern(ruleID) = focus else { return }
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(ruleID, anchor: .top)
                    }
                }
            }
        }
    }

    private var rulesListHeight: CGFloat {
        min(max(CGFloat(settings.configuration.rules.count) * 41, 82), 390)
    }
}

private struct MenuBarRuleRow: View {
    @Binding var rule: RoutingRule
    let profiles: [DiaProfile]
    let canMoveUp: Bool
    let canMoveDown: Bool
    @FocusState.Binding var focusedField: RuleEditorFocus?
    let move: (Int) -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ruleOptionsMenu

            TextField(patternPlaceholder, text: $rule.pattern)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .foregroundStyle(rule.isEnabled ? .primary : .secondary)
                .focused($focusedField, equals: .pattern(rule.id))
                .onSubmit {
                    focusedField = nil
                }
                .accessibilityLabel("\(rule.matchType.label) pattern")

            Picker("Profile", selection: $rule.profileID) {
                ForEach(profiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 110)
            .focused($focusedField, equals: .profile(rule.id))

            Toggle("Enabled", isOn: $rule.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .focused($focusedField, equals: .enabled(rule.id))
        }
        .frame(height: 40)
        .contentShape(Rectangle())
        .contextMenu {
            ruleActions
        }
    }

    private var patternPlaceholder: String {
        switch rule.matchType {
        case .domain:
            "example.com"
        case .urlContains:
            "URL contains"
        case .regularExpression:
            "Regular expression"
        }
    }

    private var ruleOptionsMenu: some View {
        ZStack {
            FaviconView(pattern: rule.pattern)
                .opacity(rule.isEnabled ? 1 : 0.55)

            Menu {
                ruleActions
            } label: {
                Color.clear
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
                    .accessibilityLabel("\(rule.matchType.label) rule options")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 16, height: 16)
            .clipped()
        }
        .frame(width: 18, height: 18)
        .clipped()
        .help("\(rule.matchType.label) rule options")
    }

    @ViewBuilder
    private var ruleActions: some View {
        Section("Match type") {
            ForEach(RuleMatchType.allCases) { matchType in
                Button {
                    rule.matchType = matchType
                } label: {
                    if rule.matchType == matchType {
                        Label(matchType.label, systemImage: "checkmark")
                    } else {
                        Text(matchType.label)
                    }
                }
            }
        }

        Divider()

        Button {
            move(-1)
        } label: {
            Label("Move Up", systemImage: "arrow.up")
        }
        .disabled(!canMoveUp)

        Button {
            move(1)
        } label: {
            Label("Move Down", systemImage: "arrow.down")
        }
        .disabled(!canMoveDown)

        Divider()

        Button(role: .destructive, action: delete) {
            Label("Delete Rule", systemImage: "trash")
        }
    }
}

private struct MenuBarSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var coordinator: RouterCoordinator

    @State private var testURLString = "https://linear.app"
    @State private var isDefaultRouter = false
    @State private var isMakingDefault = false

    let hasAccessibilityPermission: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statusCard
                profilesCard
                testRoutingCard
                resetCard
            }
            .padding(16)
        }
        .frame(height: 390)
        .onAppear {
            refreshDefaultBrowserStatus()
            settings.syncProfilesFromDia()
        }
    }

    private var statusCard: some View {
        SettingsCard(title: "Status") {
            settingsRow("Default browser") {
                if isDefaultRouter {
                    Label("Default", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Make Default") {
                        makeDefaultRouter()
                    }
                    .disabled(isMakingDefault)
                }
            }

            cardDivider

            settingsRow("Accessibility") {
                if hasAccessibilityPermission {
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Open System Settings…") {
                        DiaController.openAccessibilitySettings()
                    }
                    .buttonStyle(.link)
                }
            }

            cardDivider

            settingsRow("Last action") {
                Text(coordinator.lastMessage)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var profilesCard: some View {
        SettingsCard(title: "Dia Profiles") {
            ForEach($settings.configuration.profiles) { $profile in
                HStack(spacing: 12) {
                    TextField("Profile name", text: $profile.name)
                        .textFieldStyle(.plain)
                        .fontWeight(.medium)

                    Picker("Shortcut", selection: $profile.shortcutNumber) {
                        ForEach(1...9, id: \.self) { number in
                            Text(settings.configuration.shortcutModifier.label(for: number))
                                .tag(number)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 86)
                }
                .frame(height: 36)

                if profile.id != settings.configuration.profiles.last?.id {
                    cardDivider
                }
            }

            cardDivider

            settingsRow("Default profile") {
                Picker("Default profile", selection: $settings.configuration.defaultProfileID) {
                    ForEach(settings.configuration.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
            }

            cardDivider

            settingsRow("Shortcut modifier") {
                Picker("Shortcut modifier", selection: $settings.configuration.shortcutModifier) {
                    ForEach(ProfileShortcutModifier.allCases) { modifier in
                        Text(modifier.symbols).tag(modifier)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
            }

            cardDivider

            HStack(spacing: 7) {
                Image(systemName: settings.diaProfilesDetected
                    ? "checkmark.circle.fill"
                    : "exclamationmark.triangle.fill")
                Text(settings.diaProfilesDetected
                    ? "Profiles detected from Dia"
                    : "Could not detect Dia profiles")
                Spacer()
                Text("\(settings.configuration.profiles.count) profiles")
            }
            .font(.caption)
            .foregroundStyle(settings.diaProfilesDetected ? Color.secondary : Color.orange)

            Text("Profile numbers and the modifier must match Dia → Settings → Shortcuts. Names can be edited when Dia's local metadata has not caught up with a rename.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var testRoutingCard: some View {
        SettingsCard(title: "Test Routing") {
            TextField("https://linear.app", text: $testURLString)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Routes to")
                    .foregroundStyle(.secondary)
                Text(matchedTestProfileName)
                    .fontWeight(.medium)
                Spacer()
                Button("Open Now") {
                    if let url = normalizedTestURL {
                        coordinator.route(url)
                    }
                }
                .disabled(normalizedTestURL == nil || coordinator.isRouting)
            }
        }
    }

    private var resetCard: some View {
        SettingsCard(title: "Rules") {
            HStack {
                Text("Restore the built-in routing rules and current detected profiles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset Defaults", role: .destructive) {
                    settings.resetToDefaults()
                }
            }
        }
    }

    private var cardDivider: some View {
        Divider()
            .padding(.vertical, 2)
    }

    private func settingsRow<Trailing: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 20)
            trailing()
        }
        .frame(minHeight: 30)
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

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            }
        }
    }
}
