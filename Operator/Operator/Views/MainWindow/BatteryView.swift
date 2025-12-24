//
//  BatteryView.swift
//  Operator
//
//  Battery and thermal monitoring view.
//

import SwiftUI

struct BatteryView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Battery Status
                if systemMonitor.batteryMetrics.isPresent {
                    BatteryStatusPanel(metrics: systemMonitor.batteryMetrics)
                } else {
                    GlassPanel(title: "Battery", icon: "battery.100") {
                        VStack(spacing: 8) {
                            Image(systemName: "powerplug.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No Battery Detected")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("This Mac is running on AC power")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }

                // Thermal Status
                ThermalStatusPanel(metrics: systemMonitor.thermalMetrics)

                // Fan Status
                if !systemMonitor.thermalMetrics.fanSpeeds.isEmpty {
                    FanStatusPanel(fans: systemMonitor.thermalMetrics.fanSpeeds)
                }

                // Battery Health (if battery present)
                if systemMonitor.batteryMetrics.isPresent {
                    BatteryHealthPanel(metrics: systemMonitor.batteryMetrics)
                }
            }
            .padding()
        }
    }
}

// MARK: - Battery Status Panel

struct BatteryStatusPanel: View {
    let metrics: BatteryMetrics

    var body: some View {
        GlassPanel(title: "Battery Status", icon: metrics.statusIcon) {
            HStack(spacing: 24) {
                // Battery gauge
                VStack(spacing: 8) {
                    BatteryGauge(
                        chargePercent: metrics.chargePercent,
                        isCharging: metrics.isCharging,
                        isOnAC: metrics.isOnAC
                    )
                    .frame(width: 120, height: 60)

                    Text(metrics.formattedTimeRemaining)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Details
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "Status", value: statusText)
                    DetailRow(label: "Charge", value: "\(Int(metrics.chargePercent))%")

                    if metrics.wattage > 0 {
                        DetailRow(
                            label: metrics.isCharging ? "Charging Rate" : "Power Draw",
                            value: String(format: "%.1f W", metrics.wattage)
                        )
                    }

                    if metrics.temperature > 0 {
                        DetailRow(
                            label: "Temperature",
                            value: String(format: "%.1f°C", metrics.temperature)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Sparkline
                if !metrics.history.isEmpty {
                    SparklineView(
                        data: metrics.history,
                        color: metrics.statusColor.swiftUIColor
                    )
                    .frame(width: 100, height: 50)
                }
            }
        }
    }

    private var statusText: String {
        if metrics.isFullyCharged {
            return "Fully Charged"
        } else if metrics.isCharging {
            return "Charging"
        } else if metrics.isOnAC {
            return "On AC Power"
        } else {
            return "On Battery"
        }
    }
}

// MARK: - Battery Gauge

struct BatteryGauge: View {
    let chargePercent: Double
    let isCharging: Bool
    let isOnAC: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Battery outline
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.3), lineWidth: 2)

                // Battery cap
                Rectangle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 4, height: 20)
                    .offset(x: geometry.size.width / 2 + 2)

                // Fill
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(fillColor)
                        .frame(width: max(0, (geometry.size.width - 8) * chargePercent / 100))
                        .padding(4)
                    Spacer(minLength: 0)
                }

                // Charging indicator
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                // Percentage
                Text("\(Int(chargePercent))%")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(chargePercent > 20 ? .white : .primary)
            }
        }
    }

    private var fillColor: Color {
        if isCharging {
            return .green
        }
        switch chargePercent {
        case 0..<10: return .red
        case 10..<20: return .orange
        case 20..<50: return .yellow
        default: return .green
        }
    }
}

// MARK: - Thermal Status Panel

struct ThermalStatusPanel: View {
    let metrics: ThermalMetrics

    var body: some View {
        GlassPanel(title: "Thermal Status", icon: metrics.thermalPressure.icon) {
            VStack(spacing: 16) {
                // Thermal pressure indicator
                HStack {
                    StatusIndicator(metrics.thermalPressure.color, size: 10)
                    Text(metrics.thermalPressure.rawValue)
                        .font(.headline)
                    Spacer()
                    Text(thermalPressureDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Temperature gauges
                HStack(spacing: 24) {
                    TemperatureGauge(
                        label: "CPU",
                        temperature: metrics.cpuTemperature,
                        history: metrics.cpuHistory
                    )

                    TemperatureGauge(
                        label: "GPU",
                        temperature: metrics.gpuTemperature,
                        history: metrics.gpuHistory
                    )
                }
            }
        }
    }

    private var thermalPressureDescription: String {
        switch metrics.thermalPressure {
        case .nominal:
            return "System is running cool"
        case .fair:
            return "System is moderately warm"
        case .serious:
            return "System is throttling to cool down"
        case .critical:
            return "System is critically hot"
        }
    }
}

// MARK: - Temperature Gauge

struct TemperatureGauge: View {
    let label: String
    let temperature: Double
    let history: [Double]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.1f°C", temperature))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(temperatureColor)
            }

            ProgressBarView(
                value: min(temperature, 100),
                status: temperatureStatus,
                height: 8
            )

            if !history.isEmpty {
                SparklineView(
                    data: history,
                    color: temperatureColor,
                    showArea: true
                )
                .frame(height: 30)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var temperatureStatus: StatusColor {
        switch temperature {
        case 0..<50: return .green
        case 50..<70: return .blue
        case 70..<85: return .yellow
        default: return .red
        }
    }

    private var temperatureColor: Color {
        temperatureStatus.swiftUIColor
    }
}

// MARK: - Fan Status Panel

struct FanStatusPanel: View {
    let fans: [FanInfo]

    var body: some View {
        GlassPanel(title: "Fans", icon: "wind") {
            VStack(spacing: 12) {
                ForEach(fans) { fan in
                    HStack(spacing: 16) {
                        Image(systemName: "fan.fill")
                            .font(.title2)
                            .foregroundColor(fanColor(for: fan))
                            .rotationEffect(.degrees(fan.currentRPM > fan.minRPM ? 360 : 0))
                            .animation(
                                fan.currentRPM > fan.minRPM
                                    ? .linear(duration: 60.0 / Double(fan.currentRPM) * 60).repeatForever(autoreverses: false)
                                    : .default,
                                value: fan.currentRPM
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(fan.name)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            ProgressBarView(
                                value: fan.speedPercent,
                                status: fanStatus(for: fan),
                                height: 6
                            )
                        }

                        Text("\(fan.currentRPM) RPM")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func fanStatus(for fan: FanInfo) -> StatusColor {
        switch fan.speedPercent {
        case 0..<30: return .green
        case 30..<60: return .blue
        case 60..<80: return .yellow
        default: return .red
        }
    }

    private func fanColor(for fan: FanInfo) -> Color {
        fanStatus(for: fan).swiftUIColor
    }
}

// MARK: - Battery Health Panel

struct BatteryHealthPanel: View {
    let metrics: BatteryMetrics

    var body: some View {
        GlassPanel(title: "Battery Health", icon: "heart.fill") {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Health")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f%%", metrics.healthPercent))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(healthColor)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Cycle Count")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(metrics.cycleCount)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }

                ProgressBarView(
                    value: metrics.healthPercent,
                    status: healthStatus,
                    height: 8
                )

                HStack {
                    DetailRow(
                        label: "Design Capacity",
                        value: "\(metrics.designCapacity) mAh"
                    )
                    Spacer()
                    DetailRow(
                        label: "Current Capacity",
                        value: "\(metrics.maxCapacity) mAh"
                    )
                }
            }
        }
    }

    private var healthStatus: StatusColor {
        switch metrics.healthPercent {
        case 80...: return .green
        case 60..<80: return .yellow
        default: return .red
        }
    }

    private var healthColor: Color {
        healthStatus.swiftUIColor
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    BatteryView()
        .environmentObject(SystemMonitor())
        .frame(width: 800, height: 600)
}
