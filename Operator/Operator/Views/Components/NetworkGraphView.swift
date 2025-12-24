//
//  NetworkGraphView.swift
//  Operator
//
//  Live upload/download chart component.
//

import SwiftUI
import Charts

struct NetworkGraphView: View {
    let uploadHistory: [Double]
    let downloadHistory: [Double]
    let showLegend: Bool

    init(
        uploadHistory: [Double],
        downloadHistory: [Double],
        showLegend: Bool = true
    ) {
        self.uploadHistory = uploadHistory
        self.downloadHistory = downloadHistory
        self.showLegend = showLegend
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showLegend {
                HStack(spacing: 16) {
                    LegendItem(color: .green, label: "Upload", value: currentUpload)
                    LegendItem(color: .blue, label: "Download", value: currentDownload)
                }
                .font(.caption)
            }

            Chart {
                // Download area
                ForEach(Array(downloadHistory.enumerated()), id: \.offset) { index, value in
                    AreaMark(
                        x: .value("Time", index),
                        y: .value("Speed", value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                // Download line
                ForEach(Array(downloadHistory.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Speed", value)
                    )
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }

                // Upload line
                ForEach(Array(uploadHistory.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Speed", value)
                    )
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let speed = value.as(Double.self) {
                            Text(ByteFormatter.formatSpeedCompact(speed))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                }
            }
            .chartYScale(domain: 0...maxSpeed)
        }
    }

    private var maxSpeed: Double {
        let maxUp = uploadHistory.max() ?? 0
        let maxDown = downloadHistory.max() ?? 0
        return max(max(maxUp, maxDown) * 1.2, 1024)  // At least 1 KB/s
    }

    private var currentUpload: String {
        ByteFormatter.formatSpeed(uploadHistory.last ?? 0)
    }

    private var currentDownload: String {
        ByteFormatter.formatSpeed(downloadHistory.last ?? 0)
    }
}

// MARK: - Legend Item

struct LegendItem: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}

// MARK: - CPU Core Graph

struct CPUCoreGraphView: View {
    let coreUsages: [Double]

    var body: some View {
        Chart {
            ForEach(Array(coreUsages.enumerated()), id: \.offset) { index, usage in
                BarMark(
                    x: .value("Core", "Core \(index)"),
                    y: .value("Usage", usage)
                )
                .foregroundStyle(StatusColor.from(percentage: usage).swiftUIColor.gradient)
                .cornerRadius(4)
            }
        }
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
    }
}

// MARK: - Preview

#Preview {
    VStack {
        NetworkGraphView(
            uploadHistory: (0..<60).map { _ in Double.random(in: 0...500_000) },
            downloadHistory: (0..<60).map { _ in Double.random(in: 0...2_000_000) }
        )
        .frame(height: 200)

        CPUCoreGraphView(coreUsages: [45, 72, 30, 88, 55, 40, 65, 50])
            .frame(height: 150)
    }
    .padding()
}
