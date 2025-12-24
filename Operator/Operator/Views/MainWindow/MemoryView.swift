//
//  MemoryView.swift
//  Operator
//
//  Detailed memory metrics view with RAM/Swap breakdown.
//

import SwiftUI
import Charts

struct MemoryView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Main memory gauge
                HStack(spacing: 16) {
                    GlassPanel(title: "RAM Usage", icon: "memorychip") {
                        HStack(spacing: 20) {
                            SemiCircularGauge(
                                value: systemMonitor.memoryMetrics.usagePercent,
                                title: "Memory",
                                valueLabel: String(format: "%.1f GB", systemMonitor.memoryMetrics.usedGB),
                                status: systemMonitor.memoryMetrics.statusColor
                            )
                            .frame(width: 150, height: 120)

                            VStack(alignment: .leading, spacing: 8) {
                                MetricRow("Total", value: String(format: "%.2f GB", systemMonitor.memoryMetrics.totalGB), icon: "square.stack.3d.up")
                                MetricRow("Used", value: String(format: "%.2f GB", systemMonitor.memoryMetrics.usedGB), icon: "square.stack.3d.up.fill")
                                MetricRow("Free", value: String(format: "%.2f GB", systemMonitor.memoryMetrics.freeGB), icon: "square.stack")
                                MetricRow("Usage", value: PercentFormatter.format(systemMonitor.memoryMetrics.usagePercent),
                                         status: systemMonitor.memoryMetrics.statusColor)
                            }

                            Spacer()
                        }
                    }
                }

                // Memory breakdown
                HStack(spacing: 16) {
                    GlassPanel(title: "Memory Breakdown", icon: "chart.pie") {
                        HStack(spacing: 20) {
                            // Pie chart
                            MemoryPieChart(metrics: systemMonitor.memoryMetrics)
                                .frame(width: 150, height: 150)

                            // Legend
                            VStack(alignment: .leading, spacing: 8) {
                                MemoryLegendItem(
                                    label: "Active",
                                    value: systemMonitor.memoryMetrics.activeBytes,
                                    color: .blue
                                )
                                MemoryLegendItem(
                                    label: "Inactive",
                                    value: systemMonitor.memoryMetrics.inactiveBytes,
                                    color: .cyan
                                )
                                MemoryLegendItem(
                                    label: "Wired",
                                    value: systemMonitor.memoryMetrics.wiredBytes,
                                    color: .orange
                                )
                                MemoryLegendItem(
                                    label: "Compressed",
                                    value: systemMonitor.memoryMetrics.compressedBytes,
                                    color: .purple
                                )
                                MemoryLegendItem(
                                    label: "Free",
                                    value: systemMonitor.memoryMetrics.freeBytes,
                                    color: .green
                                )
                            }

                            Spacer()
                        }
                    }
                }

                // Memory history
                GlassPanel(title: "Memory History", icon: "chart.line.uptrend.xyaxis") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            StatusIndicator(systemMonitor.memoryMetrics.statusColor)
                            Text("Current: \(PercentFormatter.format(systemMonitor.memoryMetrics.usagePercent))")
                                .font(.caption)

                            Spacer()

                            if let avg = averageUsage {
                                Text("Avg: \(PercentFormatter.format(avg))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if systemMonitor.memoryMetrics.history.isEmpty {
                            Text("Collecting data…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
                        } else {
                            Chart {
                                ForEach(Array(systemMonitor.memoryMetrics.history.enumerated()), id: \.offset) { index, value in
                                    AreaMark(
                                        x: .value("Time", index),
                                        y: .value("Usage", value)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.4), Color.purple.opacity(0.1)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)

                                    LineMark(
                                        x: .value("Time", index),
                                        y: .value("Usage", value)
                                    )
                                    .foregroundStyle(Color.purple)
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

                // Swap usage
                if systemMonitor.memoryMetrics.swapTotalBytes > 0 {
                    GlassPanel(title: "Swap Memory", icon: "arrow.left.arrow.right.square") {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Used")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.2f GB", systemMonitor.memoryMetrics.swapUsedGB))
                                        .font(.title3)
                                        .fontWeight(.medium)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Total")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.2f GB", systemMonitor.memoryMetrics.swapTotalGB))
                                        .font(.title3)
                                        .fontWeight(.medium)
                                }
                            }

                            ProgressBarView(
                                value: systemMonitor.memoryMetrics.swapUsagePercent,
                                status: StatusColor.from(percentage: systemMonitor.memoryMetrics.swapUsagePercent),
                                height: 12
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var averageUsage: Double? {
        let history = systemMonitor.memoryMetrics.history
        guard !history.isEmpty else { return nil }
        return history.reduce(0, +) / Double(history.count)
    }
}

// MARK: - Memory Pie Chart

struct MemoryPieChart: View {
    let metrics: MemoryMetrics

    private var segments: [(value: Double, color: Color)] {
        let total = Double(metrics.totalBytes)
        guard total > 0 else { return [] }

        return [
            (Double(metrics.activeBytes) / total, .blue),
            (Double(metrics.inactiveBytes) / total, .cyan),
            (Double(metrics.wiredBytes) / total, .orange),
            (Double(metrics.compressedBytes) / total, .purple),
            (Double(metrics.freeBytes) / total, .green)
        ]
    }

    var body: some View {
        ZStack {
            ForEach(Array(segmentAngles.enumerated()), id: \.offset) { index, angles in
                PieSlice(startAngle: angles.start, endAngle: angles.end)
                    .fill(segments[index].color)
            }

            // Center hole for donut effect
            Circle()
                .fill(Color(NSColor.windowBackgroundColor))
                .frame(width: 80, height: 80)

            // Center label
            VStack(spacing: 2) {
                Text(PercentFormatter.formatInt(metrics.usagePercent))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("used")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var segmentAngles: [(start: Angle, end: Angle)] {
        var angles: [(Angle, Angle)] = []
        var currentAngle: Double = -90

        for segment in segments {
            let segmentAngle = segment.value * 360
            angles.append((.degrees(currentAngle), .degrees(currentAngle + segmentAngle)))
            currentAngle += segmentAngle
        }

        return angles
    }
}

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()

        return path
    }
}

// MARK: - Memory Legend Item

struct MemoryLegendItem: View {
    let label: String
    let value: UInt64
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(ByteFormatter.formatBytes(value))
                .font(.caption)
                .monospacedDigit()
        }
    }
}

// MARK: - Preview

#Preview {
    MemoryView()
        .environmentObject(SystemMonitor())
        .frame(width: 900, height: 700)
}
