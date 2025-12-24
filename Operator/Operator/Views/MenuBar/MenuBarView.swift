//
//  MenuBarView.swift
//  Operator
//
//  Menu bar popover content showing quick system overview.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("Operator")
                    .font(.headline)

                Spacer()

                Button(action: openMainWindow) {
                    Image(systemName: "macwindow")
                        .font(.caption)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .allowsHitTesting(true)
                .help("Open Main Window")
            }

            Divider()

            // Quick metrics
            VStack(spacing: 8) {
                // CPU
                QuickMetricRow(
                    icon: "cpu",
                    label: "CPU",
                    value: PercentFormatter.formatInt(systemMonitor.cpuMetrics.totalUsage),
                    status: systemMonitor.cpuMetrics.statusColor,
                    sparkline: systemMonitor.cpuMetrics.history
                )

                // Memory
                QuickMetricRow(
                    icon: "memorychip",
                    label: "Memory",
                    value: String(format: "%.1f GB", systemMonitor.memoryMetrics.usedGB),
                    status: systemMonitor.memoryMetrics.statusColor,
                    sparkline: systemMonitor.memoryMetrics.history
                )

                Divider()

                // Network speeds
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                                    Image(systemName: "arrow.up")
                                        .foregroundColor(.green)
                                        .font(.system(size: 13))
                        Text(systemMonitor.networkMetrics.formattedUploadSpeed)
                            .font(.system(size: 13, design: .monospaced))
                    }

                    HStack(spacing: 4) {
                                    Image(systemName: "arrow.down")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 13))
                        Text(systemMonitor.networkMetrics.formattedDownloadSpeed)
                            .font(.system(size: 13, design: .monospaced))
                    }

                    Spacer()

                    StatusIndicator(systemMonitor.networkMetrics.isConnected ? .green : .red, size: 6)
                    Text(systemMonitor.networkMetrics.connectionType)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Top processes
            VStack(alignment: .leading, spacing: 4) {
                Text("Top Processes")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(Array(systemMonitor.processes.prefix(3))) { process in
                    HStack {
                        Text(process.name)
                            .font(.caption)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(PercentFormatter.format(process.cpuUsage, decimals: 1))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(process.cpuStatusColor.swiftUIColor)
                    }
                }
            }

            Divider()

            // Quick Actions
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Actions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)

                QuickActionButton(
                    icon: "stethoscope",
                    title: "Network Diagnostics",
                    color: .blue
                ) {
                    openMainWindow()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .switchTab, object: 3)
                    }
                }

                QuickActionButton(
                    icon: "list.bullet.rectangle",
                    title: "View Processes",
                    color: .purple
                ) {
                    openMainWindow()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .switchTab, object: 4)
                    }
                }

                QuickActionButton(
                    icon: "arrow.clockwise",
                    title: "Refresh Now",
                    color: .orange
                ) {
                    systemMonitor.forceRefresh()
                }
            }

            Divider()

            // Footer actions
            HStack {
                Button("Settings...") {
                    openSettings()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .allowsHitTesting(true)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.red)
                .allowsHitTesting(true)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

// MARK: - Quick Metric Row

struct QuickMetricRow: View {
    let icon: String
    let label: String
    let value: String
    let status: StatusColor
    let sparkline: [Double]

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(status.swiftUIColor)
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .frame(width: 50, alignment: .leading)

            SparklineView(data: sparkline, color: status.swiftUIColor, showArea: false)
                .frame(height: 16)

            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .fontWeight(.medium)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .allowsHitTesting(true)
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .environmentObject(SystemMonitor())
}
