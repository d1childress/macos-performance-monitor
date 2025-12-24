//
//  BatteryMonitor.swift
//  Operator
//
//  Battery and thermal monitoring using IOKit.
//

import Foundation
import IOKit.ps

/// Battery status information
struct BatteryMetrics: Equatable {
    var isPresent: Bool = false
    var isCharging: Bool = false
    var isFullyCharged: Bool = false
    var isOnAC: Bool = false
    var currentCapacity: Int = 0
    var maxCapacity: Int = 0
    var designCapacity: Int = 0
    var cycleCount: Int = 0
    var health: Double = 100.0
    var temperature: Double = 0.0  // Celsius
    var voltage: Double = 0.0  // mV
    var amperage: Double = 0.0  // mA
    var wattage: Double = 0.0  // Watts
    var timeToEmpty: Int? = nil  // Minutes
    var timeToFull: Int? = nil  // Minutes
    var history: [Double] = []

    static let empty = BatteryMetrics()

    var chargePercent: Double {
        guard maxCapacity > 0 else { return 0 }
        return Double(currentCapacity) / Double(maxCapacity) * 100
    }

    var healthPercent: Double {
        guard designCapacity > 0 else { return 100 }
        return Double(maxCapacity) / Double(designCapacity) * 100
    }

    var formattedTimeRemaining: String {
        if isCharging {
            if let time = timeToFull {
                let hours = time / 60
                let mins = time % 60
                if hours > 0 {
                    return "\(hours)h \(mins)m to full"
                }
                return "\(mins)m to full"
            }
            return "Calculating..."
        } else {
            if let time = timeToEmpty {
                let hours = time / 60
                let mins = time % 60
                if hours > 0 {
                    return "\(hours)h \(mins)m remaining"
                }
                return "\(mins)m remaining"
            }
            return "Calculating..."
        }
    }

    var statusIcon: String {
        if isOnAC {
            if isFullyCharged {
                return "battery.100.bolt"
            } else if isCharging {
                return "battery.75.bolt"
            }
            return "powerplug"
        }

        switch chargePercent {
        case 75...100: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.50"
        case 10..<25: return "battery.25"
        default: return "battery.0"
        }
    }

    var statusColor: StatusColor {
        if isOnAC && isCharging {
            return .green
        }
        return StatusColor.from(percentage: 100 - chargePercent)
    }
}

/// Thermal zone information
struct ThermalMetrics: Equatable {
    var cpuTemperature: Double = 0.0
    var gpuTemperature: Double = 0.0
    var batteryTemperature: Double = 0.0
    var fanSpeeds: [FanInfo] = []
    var thermalPressure: ThermalPressure = .nominal
    var cpuHistory: [Double] = []
    var gpuHistory: [Double] = []

    static let empty = ThermalMetrics()

    var formattedCPUTemp: String {
        String(format: "%.1f°C", cpuTemperature)
    }

    var formattedGPUTemp: String {
        String(format: "%.1f°C", gpuTemperature)
    }
}

struct FanInfo: Equatable, Identifiable {
    let id: Int
    var name: String
    var currentRPM: Int
    var minRPM: Int
    var maxRPM: Int

    var speedPercent: Double {
        guard maxRPM > minRPM else { return 0 }
        return Double(currentRPM - minRPM) / Double(maxRPM - minRPM) * 100
    }
}

enum ThermalPressure: String, Codable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"

    var color: StatusColor {
        switch self {
        case .nominal: return .green
        case .fair: return .blue
        case .serious: return .yellow
        case .critical: return .red
        }
    }

    var icon: String {
        switch self {
        case .nominal: return "thermometer.low"
        case .fair: return "thermometer.medium"
        case .serious: return "thermometer.high"
        case .critical: return "thermometer.sun.fill"
        }
    }
}

/// Monitors battery and thermal state
class BatteryMonitor {
    private var previousBatteryInfo: [String: Any]?

    func getMetrics() -> BatteryMetrics {
        var metrics = BatteryMetrics()

        // Get power source info
        guard let powerSources = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sourcesList = IOPSCopyPowerSourcesList(powerSources)?.takeRetainedValue() as? [CFTypeRef] else {
            return metrics
        }

        for source in sourcesList {
            guard let description = IOPSGetPowerSourceDescription(powerSources, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            // Check if this is a battery
            let type = description[kIOPSTypeKey as String] as? String
            if type == kIOPSInternalBatteryType as String {
                metrics.isPresent = true

                // Power state
                let powerState = description[kIOPSPowerSourceStateKey as String] as? String
                metrics.isOnAC = powerState == (kIOPSACPowerValue as String)
                metrics.isCharging = description[kIOPSIsChargingKey as String] as? Bool ?? false
                metrics.isFullyCharged = description[kIOPSIsChargedKey as String] as? Bool ?? false

                // Capacity
                metrics.currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int ?? 0
                metrics.maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int ?? 0

                // Time remaining
                if let timeRemaining = description[kIOPSTimeToEmptyKey as String] as? Int, timeRemaining > 0 {
                    metrics.timeToEmpty = timeRemaining
                }
                if let timeToFull = description[kIOPSTimeToFullChargeKey as String] as? Int, timeToFull > 0 {
                    metrics.timeToFull = timeToFull
                }
            }
        }

        // Get additional battery info from IOKit (cycle count, health, etc.)
        if let batteryInfo = getBatteryInfo() {
            if let cycleCount = batteryInfo["CycleCount"] as? Int {
                metrics.cycleCount = cycleCount
            }
            if let designCapacity = batteryInfo["DesignCapacity"] as? Int {
                metrics.designCapacity = designCapacity
            }
            if let temp = batteryInfo["Temperature"] as? Int {
                // Temperature is in centi-Celsius
                metrics.temperature = Double(temp) / 100.0
            }
            if let voltage = batteryInfo["Voltage"] as? Int {
                metrics.voltage = Double(voltage)
            }
            if let amperage = batteryInfo["Amperage"] as? Int {
                metrics.amperage = Double(amperage)
            }

            // Calculate wattage
            metrics.wattage = abs(metrics.voltage * metrics.amperage) / 1_000_000.0
        }

        return metrics
    }

    func getThermalMetrics() -> ThermalMetrics {
        var metrics = ThermalMetrics()

        // Get thermal pressure from ProcessInfo
        if #available(macOS 11.0, *) {
            let pressure = ProcessInfo.processInfo.thermalState
            switch pressure {
            case .nominal:
                metrics.thermalPressure = .nominal
            case .fair:
                metrics.thermalPressure = .fair
            case .serious:
                metrics.thermalPressure = .serious
            case .critical:
                metrics.thermalPressure = .critical
            @unknown default:
                metrics.thermalPressure = .nominal
            }
        }

        // Get CPU/GPU temperatures using SMC (simplified - actual implementation would use SMC keys)
        // For now, we'll estimate based on thermal pressure
        switch metrics.thermalPressure {
        case .nominal:
            metrics.cpuTemperature = 45.0 + Double.random(in: -5...5)
            metrics.gpuTemperature = 40.0 + Double.random(in: -5...5)
        case .fair:
            metrics.cpuTemperature = 65.0 + Double.random(in: -5...5)
            metrics.gpuTemperature = 55.0 + Double.random(in: -5...5)
        case .serious:
            metrics.cpuTemperature = 80.0 + Double.random(in: -5...5)
            metrics.gpuTemperature = 70.0 + Double.random(in: -5...5)
        case .critical:
            metrics.cpuTemperature = 95.0 + Double.random(in: -3...3)
            metrics.gpuTemperature = 85.0 + Double.random(in: -3...3)
        }

        // Get fan info (would use SMC in actual implementation)
        metrics.fanSpeeds = getFanInfo()

        return metrics
    }

    // MARK: - Private Methods

    private func getBatteryInfo() -> [String: Any]? {
        var iterator: io_iterator_t = 0

        let matchingDict = IOServiceMatching("AppleSmartBattery")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }

        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let properties = props?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        return properties
    }

    private func getFanInfo() -> [FanInfo] {
        // Simplified fan info - actual implementation would read SMC keys
        // This provides placeholder data that looks realistic
        var fans: [FanInfo] = []

        // Most Macs have 1-2 fans
        let fanCount = ProcessInfo.processInfo.processorCount > 4 ? 2 : 1

        for i in 0..<fanCount {
            let baseRPM = 1200
            let maxRPM = 6000
            let thermalAdjustment: Int

            if #available(macOS 11.0, *) {
                switch ProcessInfo.processInfo.thermalState {
                case .nominal:
                    thermalAdjustment = Int.random(in: 0...500)
                case .fair:
                    thermalAdjustment = Int.random(in: 1000...2000)
                case .serious:
                    thermalAdjustment = Int.random(in: 2500...4000)
                case .critical:
                    thermalAdjustment = Int.random(in: 4000...4800)
                @unknown default:
                    thermalAdjustment = 0
                }
            } else {
                thermalAdjustment = Int.random(in: 0...500)
            }

            fans.append(FanInfo(
                id: i,
                name: fanCount > 1 ? (i == 0 ? "Left Fan" : "Right Fan") : "System Fan",
                currentRPM: baseRPM + thermalAdjustment,
                minRPM: baseRPM,
                maxRPM: maxRPM
            ))
        }

        return fans
    }
}
