//
//  CPUView.swift
//  Operator
//
//  Detailed CPU metrics view with per-core usage.
//

import SwiftUI
import Charts

struct CPUView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Main CPU gauge
                HStack(spacing: 16) {
                    GlassPanel(title: "Total CPU Usage", icon: "cpu") {
                        HStack(spacing: 20) {
                            SemiCircularGauge(
                                value: systemMonitor.cpuMetrics.totalUsage,
                                title: "CPU",
                                status: systemMonitor.cpuMetrics.statusColor
                            )
                            .frame(width: 150, height: 120)

                            VStack(alignment: .leading, spacing: 8) {
                                MetricRow("Physical Cores", value: "\(systemMonitor.cpuMetrics.coreCount)", icon: "cpu")
                                MetricRow("Logical Cores", value: "\(systemMonitor.cpuMetrics.threadCount)", icon: "cpu.fill")
                                MetricRow("Idle", value: PercentFormatter.format(systemMonitor.cpuMetrics.idleUsage), icon: "moon")

                                if let freq = systemMonitor.cpuMetrics.frequency {
                                    MetricRow("Frequency", value: String(format: "%.0f MHz", freq), icon: "waveform")
                                }
                            }

                            Spacer()
                        }
                    }
                }

                // CPU history chart
                GlassPanel(title: "CPU History", icon: "chart.line.uptrend.xyaxis") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            StatusIndicator(systemMonitor.cpuMetrics.statusColor)
                            Text("Current: \(PercentFormatter.format(systemMonitor.cpuMetrics.totalUsage))")
                                .font(.caption)

                            Spacer()

                            if let avg = averageUsage {
                                Text("Avg: \(PercentFormatter.format(avg))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let max = maxUsage {
                                Text("Max: \(PercentFormatter.format(max))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if systemMonitor.cpuMetrics.history.isEmpty {
                            Text("Collecting data…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
                        } else {
                            Chart {
                                ForEach(Array(systemMonitor.cpuMetrics.history.enumerated()), id: \.offset) { index, value in
                                    AreaMark(
                                        x: .value("Time", index),
                                        y: .value("Usage", value)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.accentColor.opacity(0.4), Color.accentColor.opacity(0.1)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)

                                    LineMark(
                                        x: .value("Time", index),
                                        y: .value("Usage", value)
                                    )
                                    .foregroundStyle(Color.accentColor)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                    .interpolationMethod(.catmullRom)
                                }
                            }
                            .chartXAxis(.hidden)
                            .chartYScale(domain: 0...100)
                            .chartYAxis {
                                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                                    AxisValueLabel {
                                        if let percent = value.as(Double.self) {
                                            Text("\(Int(percent))%")
                                                .font(.caption2)
                                        }
                                    }
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                        .foregroundStyle(Color.secondary.opacity(0.3))
                                }
                            }
                            .frame(height: 150)
                        }
                    }
                }

                // Per-core usage
                GlassPanel(title: "Per-Core Usage", icon: "square.grid.3x3") {
                    if systemMonitor.cpuMetrics.coreUsages.isEmpty {
                        Text("Loading core data...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            // Bar chart
                            CPUCoreGraphView(coreUsages: systemMonitor.cpuMetrics.coreUsages)
                                .frame(height: 150)

                            Divider()

                            // Grid of core values
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(8, systemMonitor.cpuMetrics.coreUsages.count)), spacing: 8) {
                                ForEach(Array(systemMonitor.cpuMetrics.coreUsages.enumerated()), id: \.offset) { index, usage in
                                    CoreUsageCell(coreIndex: index, usage: usage)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var averageUsage: Double? {
        let history = systemMonitor.cpuMetrics.history
        guard !history.isEmpty else { return nil }
        return history.reduce(0, +) / Double(history.count)
    }

    private var maxUsage: Double? {
        systemMonitor.cpuMetrics.history.max()
    }
}

// MARK: - Core Usage Cell

struct CoreUsageCell: View {
    let coreIndex: Int
    let usage: Double

    private var status: StatusColor {
        StatusColor.from(percentage: usage)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: min(1, usage / 100))
                    .stroke(status.swiftUIColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(usage))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .frame(width: 36, height: 36)

            Text("C\(coreIndex)")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    CPUView()
        .environmentObject(SystemMonitor())
        .frame(width: 900, height: 700)
}
