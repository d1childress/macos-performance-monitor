//
//  GlassPanel.swift
//  Operator
//
//  Liquid Glass effect wrapper component.
//

import SwiftUI

struct GlassPanel<Content: View>: View {
    let title: String?
    let icon: String?
    let content: Content

    init(
        title: String? = nil,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                panelHeader
            }

            content
        }
        .padding(14)
        .background(glassBackground)
        .overlay(glassBorder)
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private var panelHeader: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor, Color.purple.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(title ?? "")
                .font(.headline)
                .foregroundColor(.primary)
        }
    }

    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.06),
                            Color.purple.opacity(0.05)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
        }
    }

    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.25),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let status: StatusColor
    let size: CGFloat

    init(_ status: StatusColor, size: CGFloat = 8) {
        self.status = status
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(status.swiftUIColor)
            .frame(width: size, height: size)
            .shadow(color: status.swiftUIColor.opacity(0.5), radius: 2)
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let label: String
    let value: String
    let icon: String?
    let status: StatusColor?

    init(
        _ label: String,
        value: String,
        icon: String? = nil,
        status: StatusColor? = nil
    ) {
        self.label = label
        self.value = value
        self.icon = icon
        self.status = status
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }

            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 6) {
                if let status = status {
                    StatusIndicator(status)
                }

                Text(value)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .frame(minWidth: 60, alignment: .trailing)
            }
        }
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    let value: Double
    let total: Double
    let status: StatusColor
    let height: CGFloat
    let showLabel: Bool

    init(
        value: Double,
        total: Double = 100,
        status: StatusColor? = nil,
        height: CGFloat = 8,
        showLabel: Bool = false
    ) {
        self.value = value
        self.total = total
        self.status = status ?? StatusColor.from(percentage: value / total * 100)
        self.height = height
        self.showLabel = showLabel
    }

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, value / total))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.primary.opacity(0.1))

                // Fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(status.swiftUIColor.gradient)
                    .frame(width: geometry.size.width * percentage)

                // Label overlay
                if showLabel {
                    Text(PercentFormatter.formatInt(percentage * 100))
                        .font(.system(size: height * 0.8, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(radius: 1)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Circular Gauge

struct CircularGauge: View {
    let value: Double
    let maxValue: Double
    let title: String
    let subtitle: String?
    let status: StatusColor
    let lineWidth: CGFloat

    init(
        value: Double,
        maxValue: Double = 100,
        title: String,
        subtitle: String? = nil,
        status: StatusColor? = nil,
        lineWidth: CGFloat = 10
    ) {
        self.value = value
        self.maxValue = maxValue
        self.title = title
        self.subtitle = subtitle
        self.status = status ?? StatusColor.from(percentage: value / maxValue * 100)
        self.lineWidth = lineWidth
    }

    private var percentage: Double {
        guard maxValue > 0 else { return 0 }
        return min(1, max(0, value / maxValue))
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: lineWidth)

                // Progress arc
                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(
                        status.swiftUIColor.gradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: percentage)

                // Center label
                VStack(spacing: 2) {
                    Text(PercentFormatter.formatInt(percentage * 100))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                }
            }
            .aspectRatio(1, contentMode: .fit)

            Text(title)
                .font(.caption)
                .foregroundColor(.primary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        GlassPanel(title: "System Overview", icon: "cpu") {
            VStack {
                MetricRow("CPU Usage", value: "45%", icon: "cpu", status: .green)
                MetricRow("Memory", value: "8.2 GB", icon: "memorychip", status: .blue)
            }
        }

        HStack {
            CircularGauge(value: 45, title: "CPU")
            CircularGauge(value: 72, title: "Memory")
            CircularGauge(value: 91, title: "Disk")
        }
        .frame(height: 100)

        ProgressBarView(value: 65, showLabel: true)
            .frame(height: 20)
    }
    .padding()
    .frame(width: 400)
}
