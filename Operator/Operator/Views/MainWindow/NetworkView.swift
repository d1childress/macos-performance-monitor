//
//  NetworkView.swift
//  Operator
//
//  Detailed network metrics view with upload/download rates and interface info.
//

import SwiftUI
import Charts
import AppKit

struct NetworkView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Connection status and speeds
                HStack(spacing: 16) {
                    GlassPanel(title: "Connection Status", icon: "wifi") {
                        HStack(spacing: 20) {
                            VStack(spacing: 8) {
                                Image(systemName: systemMonitor.networkMetrics.isConnected ? "wifi" : "wifi.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(systemMonitor.networkMetrics.isConnected ? .green : .red)

                                Text(systemMonitor.networkMetrics.connectionType)
                                    .font(.headline)

                                HStack {
                                    StatusIndicator(systemMonitor.networkMetrics.isConnected ? .green : .red)
                                    Text(systemMonitor.networkMetrics.isConnected ? "Connected" : "Disconnected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(width: 120)

                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                // Upload speed
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)

                                    VStack(alignment: .leading) {
                                        Text("Upload")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(systemMonitor.networkMetrics.formattedUploadSpeed)
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .monospacedDigit()
                                    }
                                }

                                // Download speed
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)

                                    VStack(alignment: .leading) {
                                        Text("Download")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(systemMonitor.networkMetrics.formattedDownloadSpeed)
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .monospacedDigit()
                                    }
                                }
                            }

                            Spacer()
                        }
                    }

                    GlassPanel(title: "Total Transfer", icon: "arrow.up.arrow.down") {
                        VStack(spacing: 16) {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "arrow.up")
                                            .foregroundColor(.green)
                                        Text("Sent")
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.caption)

                                    Text(systemMonitor.networkMetrics.formattedTotalSent)
                                        .font(.title3)
                                        .fontWeight(.medium)
                                        .monospacedDigit()
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "arrow.down")
                                            .foregroundColor(.blue)
                                        Text("Received")
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.caption)

                                    Text(systemMonitor.networkMetrics.formattedTotalReceived)
                                        .font(.title3)
                                        .fontWeight(.medium)
                                        .monospacedDigit()
                                }

                                Spacer()
                            }
                        }
                    }
                }

                // Live network graph
                GlassPanel(title: "Network Activity", icon: "chart.line.uptrend.xyaxis") {
                    if systemMonitor.networkMetrics.uploadHistory.isEmpty && systemMonitor.networkMetrics.downloadHistory.isEmpty {
                        Text("Collecting data…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
                    } else {
                        NetworkGraphView(
                            uploadHistory: systemMonitor.networkMetrics.uploadHistory,
                            downloadHistory: systemMonitor.networkMetrics.downloadHistory
                        )
                        .frame(height: 200)
                    }
                }

                // Network interfaces
                GlassPanel(title: "Network Interfaces", icon: "network") {
                    if systemMonitor.networkMetrics.interfaces.isEmpty {
                        Text("No network interfaces found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                                Text("Interface")
                                    .frame(width: 120, alignment: .leading)
                                Text("IP Address")
                                    .frame(width: 150, alignment: .leading)
                                Text("Upload")
                                    .frame(width: 100, alignment: .trailing)
                                Text("Download")
                                    .frame(width: 100, alignment: .trailing)
                                Text("Status")
                                    .frame(width: 60, alignment: .center)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.05))

                            Divider()

                            // Rows
                            ForEach(systemMonitor.networkMetrics.interfaces) { iface in
                                NetworkInterfaceRow(interface: iface)
                            }
                        }
                        .background(Color.primary.opacity(0.02))
                        .cornerRadius(8)
                    }
                }

            }
            .padding()
        }
    }
}

// MARK: - Network Interface Row

struct NetworkInterfaceRow: View {
    let interface: NetworkInterfaceInfo

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: interface.icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(interface.displayName)
                        .font(.subheadline)
                    Text(interface.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, alignment: .leading)

            Text(interface.ipAddress ?? "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: 150, alignment: .leading)

            Text(ByteFormatter.formatSpeed(interface.uploadSpeed))
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(.green)
                .frame(width: 100, alignment: .trailing)

            Text(ByteFormatter.formatSpeed(interface.downloadSpeed))
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(.blue)
                .frame(width: 100, alignment: .trailing)

            StatusIndicator(interface.isUp ? .green : .red)
                .frame(width: 60)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Preview

#Preview {
    NetworkView()
        .environmentObject(SystemMonitor())
        .frame(width: 900, height: 700)
}
