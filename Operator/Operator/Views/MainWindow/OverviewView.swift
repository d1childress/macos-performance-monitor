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
            HStack {
                Image(systemName: "desktopcomputer")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
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
        }
    }
}

// MARK: - Preview

#Preview {
    OverviewView()
        .environmentObject(SystemMonitor())
        .frame(width: 900, height: 700)
}
