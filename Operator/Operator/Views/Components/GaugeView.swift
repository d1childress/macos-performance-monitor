//
//  GaugeView.swift
//  Operator
//
//  Circular and linear gauge components.
//

import SwiftUI

// MARK: - Semi-Circular Gauge

struct SemiCircularGauge: View {
    let value: Double
    let maxValue: Double
    let title: String
    let valueLabel: String?
    let status: StatusColor

    init(
        value: Double,
        maxValue: Double = 100,
        title: String,
        valueLabel: String? = nil,
        status: StatusColor? = nil
    ) {
        self.value = value
        self.maxValue = maxValue
        self.title = title
        self.valueLabel = valueLabel
        self.status = status ?? StatusColor.from(percentage: value / maxValue * 100)
    }

    private var percentage: Double {
        guard maxValue > 0 else { return 0 }
        return min(1, max(0, value / maxValue))
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                // Background arc
                SemiCircle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 12)

                // Progress arc
                SemiCircle()
                    .trim(from: 0, to: percentage)
                    .stroke(
                        status.swiftUIColor.gradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .animation(.easeInOut(duration: 0.3), value: percentage)

                // Center value - positioned at bottom center of the arc
                VStack(spacing: 2) {
                    Text(valueLabel ?? PercentFormatter.formatInt(percentage * 100))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .frame(minWidth: 60)

                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }
        }
    }
}

struct SemiCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY - 10)
        let radius = min(rect.width, rect.height * 2) / 2 - 10

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )

        return path
    }
}

// MARK: - Mini Gauge (for menu bar or compact views)

struct MiniGauge: View {
    let value: Double
    let icon: String
    let color: Color

    init(value: Double, icon: String, color: Color? = nil) {
        self.value = value
        self.icon = icon
        self.color = color ?? StatusColor.from(percentage: value).swiftUIColor
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 40, height: 6)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 40 * min(1, max(0, value / 100)), height: 6)
            }

            Text("\(Int(value))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }
}

// MARK: - Speed Gauge (for network speeds)

struct SpeedGauge: View {
    let uploadSpeed: Double
    let downloadSpeed: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "arrow.up")
                    .foregroundColor(.green)
                    .font(.system(size: 10))

                Text(ByteFormatter.formatSpeed(uploadSpeed))
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 70, alignment: .trailing)
            }

            HStack {
                Image(systemName: "arrow.down")
                    .foregroundColor(.blue)
                    .font(.system(size: 10))

                Text(ByteFormatter.formatSpeed(downloadSpeed))
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 70, alignment: .trailing)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        HStack {
            SemiCircularGauge(value: 45, title: "CPU")
            SemiCircularGauge(value: 72, title: "Memory")
            SemiCircularGauge(value: 91, title: "Disk")
        }
        .frame(height: 100)

        VStack(spacing: 8) {
            MiniGauge(value: 45, icon: "cpu")
            MiniGauge(value: 72, icon: "memorychip")
            MiniGauge(value: 91, icon: "internaldrive")
        }

        SpeedGauge(uploadSpeed: 125_000, downloadSpeed: 2_500_000)
    }
    .padding()
    .frame(width: 400)
}
