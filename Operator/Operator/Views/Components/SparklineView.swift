//
//  SparklineView.swift
//  Operator
//
//  Mini trend graph component.
//

import SwiftUI
import Charts

struct SparklineView: View {
    let data: [Double]
    let color: Color
    let showArea: Bool

    init(
        data: [Double],
        color: Color = .accentColor,
        showArea: Bool = true
    ) {
        self.data = data
        self.color = color
        self.showArea = showArea
    }

    var body: some View {
        if data.isEmpty {
            Rectangle()
                .fill(Color.clear)
        } else {
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                    if showArea {
                        AreaMark(
                            x: .value("Time", index),
                            y: .value("Value", value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    LineMark(
                        x: .value("Time", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...maxValue)
        }
    }

    private var maxValue: Double {
        max(data.max() ?? 100, 10) * 1.1
    }
}

// MARK: - Network Speed Sparkline

struct NetworkSparklineView: View {
    let uploadData: [Double]
    let downloadData: [Double]

    var body: some View {
        Chart {
            // Download (below x-axis conceptually, but we show both positive)
            ForEach(Array(downloadData.enumerated()), id: \.offset) { index, value in
                AreaMark(
                    x: .value("Time", index),
                    y: .value("Download", value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Time", index),
                    y: .value("Download", value)
                )
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }

            // Upload
            ForEach(Array(uploadData.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Time", index),
                    y: .value("Upload", value)
                )
                .foregroundStyle(Color.green)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...maxValue)
    }

    private var maxValue: Double {
        let maxUpload = uploadData.max() ?? 0
        let maxDownload = downloadData.max() ?? 0
        return max(max(maxUpload, maxDownload), 1024) * 1.1
    }
}

// MARK: - Preview

#Preview {
    VStack {
        SparklineView(
            data: [10, 25, 15, 30, 45, 35, 50, 40, 60, 55],
            color: .green
        )
        .frame(height: 50)

        NetworkSparklineView(
            uploadData: [100, 250, 150, 300, 450, 350, 500, 400, 600, 550],
            downloadData: [500, 800, 600, 1200, 900, 1500, 1100, 1800, 1400, 2000]
        )
        .frame(height: 80)
    }
    .padding()
}
