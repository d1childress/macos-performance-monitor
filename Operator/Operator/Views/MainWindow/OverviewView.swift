//
//  OverviewView.swift
//  Operator
//
//  Dashboard with all key metrics at a glance.
//

import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // System info header
                SystemInfoHeader()

                // Main gauges
                HStack(spacing: 16) {
                    GlassPanel(title: "CPU", icon: "cpu") {
                        VStack(spacing: 12) {
                            CircularGauge(
                                value: systemMonitor.cpuMetrics.totalUsage,
                                title: "Usage",
                                subtitle: "\(systemMonitor.cpuMetrics.coreCount) cores"
                            )
                            .frame(height: 120)

                            if systemMonitor.cpuMetrics.history.isEmpty {
                                Text("Collecting data…")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
                            } else {
                                SparklineView(
                                    data: systemMonitor.cpuMetrics.history,
                                    color: systemMonitor.cpuMetrics.statusColor.swiftUIColor
                                )
                                .frame(height: 40)
                            }
                        }
                    }

                    GlassPanel(title: "Memory", icon: "memorychip") {
                        VStack(spacing: 12) {
                            CircularGauge(
                                value: systemMonitor.memoryMetrics.usagePercent,
                                title: "Usage",
                                subtitle: String(format: "%.1f / %.1f GB",
                                                systemMonitor.memoryMetrics.usedGB,
                                                systemMonitor.memoryMetrics.totalGB)
                            )
                            .frame(height: 120)

                            if systemMonitor.memoryMetrics.history.isEmpty {
                                Text("Collecting data…")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
                            } else {
                                SparklineView(
                                    data: systemMonitor.memoryMetrics.history,
                                    color: systemMonitor.memoryMetrics.statusColor.swiftUIColor
                                )
                                .frame(height: 40)
                            }
                        }
                    }

                    GlassPanel(title: "Network", icon: "network") {
                        VStack(spacing: 12) {
                            SpeedGauge(
                                uploadSpeed: systemMonitor.networkMetrics.uploadSpeed,
                                downloadSpeed: systemMonitor.networkMetrics.downloadSpeed
                            )
                            .frame(height: 50)

                            if systemMonitor.networkMetrics.uploadHistory.isEmpty && systemMonitor.networkMetrics.downloadHistory.isEmpty {
                                Text("Collecting data…")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                            } else {
                                NetworkSparklineView(
                                    uploadData: systemMonitor.networkMetrics.uploadHistory,
                                    downloadData: systemMonitor.networkMetrics.downloadHistory
                                )
                                .frame(height: 80)
                            }

                            HStack {
                                StatusIndicator(systemMonitor.networkMetrics.isConnected ? .green : .red)
                                Text(systemMonitor.networkMetrics.connectionType)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Disk and quick info
                HStack(spacing: 16) {
                    // Disk usage
                    GlassPanel(title: "Disk", icon: "internaldrive") {
                        VStack(spacing: 8) {
                            ForEach(systemMonitor.diskMetrics.volumes) { volume in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(volume.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(String(format: "%.1f / %.1f GB",
                                                   volume.usedGB, volume.totalGB))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    ProgressBarView(
                                        value: volume.usagePercent,
                                        status: volume.statusColor,
                                        height: 6
                                    )
                                }
                            }

                            if systemMonitor.diskMetrics.volumes.isEmpty {
                                Text("No volumes found")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Top processes quick view
                    GlassPanel(title: "Top Processes", icon: "list.bullet.rectangle") {
                        VStack(spacing: 6) {
                            ForEach(Array(systemMonitor.processes.prefix(5))) { process in
                                HStack {
                                    Text(process.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Text(PercentFormatter.format(process.cpuUsage, decimals: 1))
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundColor(process.cpuStatusColor.swiftUIColor)
                                        .frame(width: 50, alignment: .trailing)
                                }
                            }

                            if systemMonitor.processes.isEmpty {
                                Text("Loading processes...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Disk I/O
                HStack(spacing: 16) {
                    GlassPanel(title: "Disk I/O", icon: "arrow.left.arrow.right") {
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "arrow.down.doc")
                                        .foregroundColor(.blue)
                                    Text("Read")
                                        .foregroundColor(.secondary)
                                }
                                Text(systemMonitor.diskMetrics.formattedReadSpeed)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "arrow.up.doc")
                                        .foregroundColor(.green)
                                    Text("Write")
                                        .foregroundColor(.secondary)
                                }
                                Text(systemMonitor.diskMetrics.formattedWriteSpeed)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                            }

                            Spacer()
                        }
                    }

                    // Network interfaces quick view
                    GlassPanel(title: "Interfaces", icon: "cable.connector") {
                        VStack(spacing: 6) {
                            ForEach(systemMonitor.networkMetrics.interfaces.filter { $0.isUp }.prefix(4)) { iface in
                                HStack {
                                    Image(systemName: iface.icon)
                                        .foregroundColor(.secondary)
                                        .frame(width: 16)

                                    Text(iface.displayName)
                                        .font(.caption)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if let ip = iface.ipAddress {
                                        Text(ip)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            if systemMonitor.networkMetrics.interfaces.isEmpty {
                                Text("No active interfaces")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - System Info Header

struct SystemInfoHeader: View {
    @EnvironmentObject var systemMonitor: SystemMonitor

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.16), Color.purple.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                            )

                        Image(systemName: "desktopcomputer")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(systemMonitor.systemInfo.modelName)
                            .font(.headline)
                        Text("macOS \(systemMonitor.systemInfo.macOSVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Uptime")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(systemMonitor.systemInfo.formattedUptime)
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                HStack(spacing: 10) {
                    InfoBadge(
                        icon: "cpu",
                        title: "CPU",
                        value: PercentFormatter.format(systemMonitor.cpuMetrics.totalUsage, decimals: 1),
                        detail: "\(systemMonitor.cpuMetrics.coreCount) cores",
                        gradient: LinearGradient(
                            colors: [Color.blue.opacity(0.35), Color.cyan.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                    InfoBadge(
                        icon: "memorychip",
                        title: "Memory",
                        value: PercentFormatter.format(systemMonitor.memoryMetrics.usagePercent, decimals: 1),
                        detail: String(format: "%.1f / %.1f GB",
                                       systemMonitor.memoryMetrics.usedGB,
                                       systemMonitor.memoryMetrics.totalGB),
                        gradient: LinearGradient(
                            colors: [Color.purple.opacity(0.32), Color.indigo.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                    InfoBadge(
                        icon: "arrow.up.arrow.down.circle",
                        title: "Network",
                        value: systemMonitor.networkMetrics.formattedDownloadSpeed,
                        detail: "Up \(systemMonitor.networkMetrics.formattedUploadSpeed)",
                        gradient: LinearGradient(
                            colors: [Color.green.opacity(0.28), Color.teal.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Badge

struct InfoBadge: View {
    let icon: String
    let title: String
    let value: String
    let detail: String
    let gradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
            }
            .foregroundColor(.primary.opacity(0.9))

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))

            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
    }
}

// MARK: - Preview

#Preview {
    OverviewView()
        .environmentObject(SystemMonitor())
        .frame(width: 900, height: 700)
}
