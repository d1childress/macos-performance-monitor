//
//  OperatorApp.swift
//  Operator
//
//  A native macOS performance monitoring application with menu bar integration.
//  Features Liquid Glass styling and network-focused utilities for pros and beginners.
//

import SwiftUI

@main
struct OperatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var systemMonitor = SystemMonitor()

    var body: some Scene {
        WindowGroup("Operator", id: "main") {
            ContentView()
                .environmentObject(systemMonitor)
                .frame(minWidth: 800, minHeight: 600)
                .withOnboarding()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Operator") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "Operator",
                            .applicationVersion: "1.0.0",
                            .credits: NSAttributedString(string: "A lightweight macOS performance monitor")
                        ]
                    )
                }
            }

            // Keyboard navigation commands
            CommandGroup(after: .sidebar) {
                Button("Refresh Now") {
                    systemMonitor.forceRefresh()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Overview") {
                    NotificationCenter.default.post(name: .switchTab, object: 0)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("CPU") {
                    NotificationCenter.default.post(name: .switchTab, object: 1)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Memory") {
                    NotificationCenter.default.post(name: .switchTab, object: 2)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Network") {
                    NotificationCenter.default.post(name: .switchTab, object: 3)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Diagnostics") {
                    NotificationCenter.default.post(name: .switchTab, object: 4)
                }
                .keyboardShortcut("5", modifiers: .command)

                Button("Processes") {
                    NotificationCenter.default.post(name: .switchTab, object: 5)
                }
                .keyboardShortcut("6", modifiers: .command)

                Button("Battery") {
                    NotificationCenter.default.post(name: .switchTab, object: 6)
                }
                .keyboardShortcut("7", modifiers: .command)

                Button("History") {
                    NotificationCenter.default.post(name: .switchTab, object: 7)
                }
                .keyboardShortcut("8", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(systemMonitor)
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(systemMonitor)
        } label: {
            MenuBarLabel()
                .environmentObject(systemMonitor)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Menu bar icon/text label
struct MenuBarLabel: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @AppStorage("menuBarDisplay") private var menuBarDisplay = MenuBarDisplayMode.networkSpeeds
    @AppStorage("menuBarTextStyle") private var menuBarTextStyle = MenuBarTextStyle.regular

    private var metricFont: Font {
        switch menuBarTextStyle {
        case .compact:
            return .system(size: 11, design: .monospaced)
        case .regular:
            return .system(size: 13, design: .monospaced)
        }
    }

    private var iconSize: CGFloat {
        menuBarTextStyle == .compact ? 11 : 13
    }

    private var spacing: CGFloat {
        menuBarTextStyle == .compact ? 2 : 4
    }

    var body: some View {
        switch menuBarDisplay {
        case .iconOnly:
            Image(systemName: "network")
        case .networkSpeeds:
            HStack(spacing: spacing) {
                Image(systemName: "arrow.up")
                    .font(.system(size: iconSize))
                Text(systemMonitor.networkMetrics.formattedUploadSpeed)
                    .font(metricFont)
                Image(systemName: "arrow.down")
                    .font(.system(size: iconSize))
                Text(systemMonitor.networkMetrics.formattedDownloadSpeed)
                    .font(metricFont)
            }
        case .cpuUsage:
            HStack(spacing: spacing) {
                Image(systemName: "cpu")
                    .font(.system(size: iconSize + 1))
                Text("\(Int(systemMonitor.cpuMetrics.totalUsage))%")
                    .font(metricFont)
            }
        }
    }
}

enum MenuBarDisplayMode: String, CaseIterable {
    case iconOnly = "Icon Only"
    case networkSpeeds = "Network Speeds"
    case cpuUsage = "CPU Usage"
}

enum MenuBarTextStyle: String, CaseIterable {
    case regular = "Regular"
    case compact = "Compact"
}

// MARK: - Notification Names

extension Notification.Name {
    static let switchTab = Notification.Name("switchTab")
}
