//
//  SettingsView.swift
//  Operator
//
//  Application preferences window.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ProfilesSettingsView()
                .tabItem {
                    Label("Profiles", systemImage: "person.2")
                }

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            MenuBarSettingsView()
                .tabItem {
                    Label("Menu Bar", systemImage: "menubar.rectangle")
                }

            AlertsSettingsView()
                .tabItem {
                    Label("Alerts", systemImage: "bell")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval = 1.0
    @AppStorage("historyLength") private var historyLength = 60
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showDockIcon") private var showDockIcon = true

    var body: some View {
        Form {
            Section {
                Picker("Refresh Interval", selection: $refreshInterval) {
                    Text("0.5 seconds").tag(0.5)
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                }

                Picker("History Length", selection: $historyLength) {
                    Text("30 seconds").tag(30)
                    Text("60 seconds").tag(60)
                    Text("120 seconds").tag(120)
                    Text("300 seconds").tag(300)
                }
            } header: {
                Text("Monitoring")
            }

            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                Toggle("Show Dock Icon", isOn: $showDockIcon)
            } header: {
                Text("Startup")
            }

            Section {
                Button("Reset Onboarding") {
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                }
                .foregroundColor(.secondary)

                Button("Clear History Data") {
                    Task { @MainActor in
                        HistoryStore.shared.clearHistory()
                    }
                }
                .foregroundColor(.red)
            } header: {
                Text("Data")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Profiles Settings

struct ProfilesSettingsView: View {
    @StateObject private var profileManager = ProfileManager.shared

    var body: some View {
        Form {
            Section {
                ForEach(UsageProfile.allCases, id: \.self) { profile in
                    HStack {
                        Image(systemName: profile.icon)
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(profile.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if profileManager.activeProfile == profile && profileManager.activeCustomProfile == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Button("Activate") {
                                profileManager.activate(profile)
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Built-in Profiles")
            }

            if !profileManager.customProfiles.isEmpty {
                Section {
                    ForEach(profileManager.customProfiles) { profile in
                        HStack {
                            Image(systemName: profile.icon)
                                .font(.title2)
                                .foregroundColor(.accentColor)
                                .frame(width: 30)

                            Text(profile.name)
                                .font(.subheadline)

                            Spacer()

                            if profileManager.activeCustomProfile?.id == profile.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Button("Activate") {
                                    profileManager.activateCustom(profile)
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.accentColor)
                            }

                            Button {
                                profileManager.deleteCustomProfile(profile)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    Text("Custom Profiles")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = ColorSchemePreference.system
    @AppStorage("accentColorChoice") private var accentColorChoice = AccentColorChoice.system

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $colorScheme) {
                    Text("System").tag(ColorSchemePreference.system)
                    Text("Light").tag(ColorSchemePreference.light)
                    Text("Dark").tag(ColorSchemePreference.dark)
                }

                Picker("Accent Color", selection: $accentColorChoice) {
                    Text("System").tag(AccentColorChoice.system)
                    Text("Blue").tag(AccentColorChoice.blue)
                    Text("Purple").tag(AccentColorChoice.purple)
                    Text("Pink").tag(AccentColorChoice.pink)
                    Text("Red").tag(AccentColorChoice.red)
                    Text("Orange").tag(AccentColorChoice.orange)
                    Text("Yellow").tag(AccentColorChoice.yellow)
                    Text("Green").tag(AccentColorChoice.green)
                }
            } header: {
                Text("Theme")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

enum ColorSchemePreference: String {
    case system, light, dark
}

enum AccentColorChoice: String {
    case system, blue, purple, pink, red, orange, yellow, green
}

// MARK: - Menu Bar Settings

struct MenuBarSettingsView: View {
    @AppStorage("menuBarDisplay") private var menuBarDisplay = MenuBarDisplayMode.networkSpeeds
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("menuBarTextStyle") private var menuBarTextStyle = MenuBarTextStyle.regular

    var body: some View {
        Form {
            Section {
                Picker("Display Mode", selection: $menuBarDisplay) {
                    Text("Icon Only").tag(MenuBarDisplayMode.iconOnly)
                    Text("Network Speeds").tag(MenuBarDisplayMode.networkSpeeds)
                    Text("CPU Usage").tag(MenuBarDisplayMode.cpuUsage)
                }

                Picker("Text Density", selection: $menuBarTextStyle) {
                    Text("Regular").tag(MenuBarTextStyle.regular)
                    Text("Compact").tag(MenuBarTextStyle.compact)
                }

                Toggle("Show Menu Bar Icon", isOn: $showMenuBarIcon)
            } header: {
                Text("Menu Bar")
            }

            Section {
                Text("The menu bar shows live system metrics. Click it to see a quick overview of your system.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Alerts Settings

struct AlertsSettingsView: View {
    @StateObject private var alertManager = AlertManager.shared

    var body: some View {
        Form {
            Section {
                ForEach(alertManager.rules) { rule in
                    AlertRuleRow(rule: rule, onUpdate: { updatedRule in
                        alertManager.updateRule(updatedRule)
                    }, onDelete: {
                        alertManager.deleteRule(rule)
                    })
                }
            } header: {
                Text("Alert Rules")
            }

            Section {
                HStack {
                    Text("Unread Alerts")
                    Spacer()
                    Text("\(alertManager.unreadCount)")
                        .foregroundColor(.secondary)
                }

                if alertManager.unreadCount > 0 {
                    Button("Mark All as Read") {
                        alertManager.markAllAsRead()
                    }
                }

                if !alertManager.events.isEmpty {
                    Button("Clear All Alerts") {
                        alertManager.clearEvents()
                    }
                    .foregroundColor(.red)
                }
            } header: {
                Text("Alert History")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AlertRuleRow: View {
    let rule: AlertRule
    let onUpdate: (AlertRule) -> Void
    let onDelete: () -> Void

    @State private var isEnabled: Bool
    @State private var threshold: Double

    init(rule: AlertRule, onUpdate: @escaping (AlertRule) -> Void, onDelete: @escaping () -> Void) {
        self.rule = rule
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._isEnabled = State(initialValue: rule.isEnabled)
        self._threshold = State(initialValue: rule.threshold)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: rule.type.icon)
                    .foregroundColor(isEnabled ? .accentColor : .secondary)

                Text(rule.type.rawValue)
                    .font(.subheadline)

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: isEnabled) { newValue in
                        var updated = rule
                        updated.isEnabled = newValue
                        onUpdate(updated)
                    }
            }

            if isEnabled && rule.type != .networkDisconnected {
                HStack {
                    Text("Threshold:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(value: $threshold, in: thresholdRange, step: thresholdStep)
                        .onChange(of: threshold) { newValue in
                            var updated = rule
                            updated.threshold = newValue
                            onUpdate(updated)
                        }

                    Text(formattedThreshold)
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var thresholdRange: ClosedRange<Double> {
        switch rule.type {
        case .cpuHigh, .cpuSustained, .memoryHigh, .memoryPressure:
            return 50...100
        case .diskSpaceLow:
            return 5...50
        case .processHighCPU:
            return 50...200
        case .processHighMemory:
            return 10...100
        default:
            return 0...100
        }
    }

    private var thresholdStep: Double {
        rule.type == .diskSpaceLow ? 1 : 5
    }

    private var formattedThreshold: String {
        switch rule.type {
        case .networkHighUpload, .networkHighDownload:
            return ByteFormatter.formatSpeed(threshold)
        default:
            return "\(Int(threshold))%"
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
