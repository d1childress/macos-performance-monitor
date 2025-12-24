//
//  SystemMetrics.swift
//  Operator
//
//  Data models for all system metrics.
//

import Foundation
import SwiftUI

// MARK: - CPU Metrics

struct CPUMetrics: Equatable {
    var totalUsage: Double = 0.0
    var userUsage: Double = 0.0
    var systemUsage: Double = 0.0
    var idleUsage: Double = 100.0
    var coreUsages: [Double] = []
    var coreCount: Int = 0
    var threadCount: Int = 0
    var frequency: Double? = nil  // MHz, Intel only
    var history: [Double] = []

    static let empty = CPUMetrics()

    var statusColor: StatusColor {
        StatusColor.from(percentage: totalUsage)
    }
}

// MARK: - Memory Metrics

struct MemoryMetrics: Equatable {
    var totalBytes: UInt64 = 0
    var usedBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var activeBytes: UInt64 = 0
    var inactiveBytes: UInt64 = 0
    var wiredBytes: UInt64 = 0
    var compressedBytes: UInt64 = 0
    var swapTotalBytes: UInt64 = 0
    var swapUsedBytes: UInt64 = 0
    var history: [Double] = []

    static let empty = MemoryMetrics()

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    var swapUsagePercent: Double {
        guard swapTotalBytes > 0 else { return 0 }
        return Double(swapUsedBytes) / Double(swapTotalBytes) * 100
    }

    var totalGB: Double { Double(totalBytes) / 1_073_741_824 }
    var usedGB: Double { Double(usedBytes) / 1_073_741_824 }
    var freeGB: Double { Double(freeBytes) / 1_073_741_824 }
    var swapTotalGB: Double { Double(swapTotalBytes) / 1_073_741_824 }
    var swapUsedGB: Double { Double(swapUsedBytes) / 1_073_741_824 }

    var statusColor: StatusColor {
        StatusColor.from(percentage: usagePercent)
    }
}

// MARK: - Network Metrics

struct NetworkMetrics: Equatable {
    var bytesSent: UInt64 = 0
    var bytesReceived: UInt64 = 0
    var uploadSpeed: Double = 0.0  // bytes per second
    var downloadSpeed: Double = 0.0  // bytes per second
    var interfaces: [NetworkInterfaceInfo] = []
    var uploadHistory: [Double] = []
    var downloadHistory: [Double] = []
    var isConnected: Bool = true
    var connectionType: String = "Unknown"

    static let empty = NetworkMetrics()

    var formattedUploadSpeed: String {
        ByteFormatter.formatSpeed(uploadSpeed)
    }

    var formattedDownloadSpeed: String {
        ByteFormatter.formatSpeed(downloadSpeed)
    }

    var formattedTotalSent: String {
        ByteFormatter.formatBytes(bytesSent)
    }

    var formattedTotalReceived: String {
        ByteFormatter.formatBytes(bytesReceived)
    }
}

struct NetworkInterfaceInfo: Equatable, Identifiable {
    let id = UUID()
    var name: String
    var displayName: String
    var ipAddress: String?
    var macAddress: String?
    var bytesSent: UInt64 = 0
    var bytesReceived: UInt64 = 0
    var uploadSpeed: Double = 0.0
    var downloadSpeed: Double = 0.0
    var isUp: Bool = false

    var icon: String {
        if name.hasPrefix("en") {
            return name == "en0" ? "wifi" : "cable.connector"
        } else if name.hasPrefix("lo") {
            return "arrow.triangle.2.circlepath"
        } else if name.hasPrefix("utun") || name.hasPrefix("ipsec") {
            return "lock.shield"
        }
        return "network"
    }
}

// MARK: - Disk Metrics

struct DiskMetrics: Equatable {
    var volumes: [VolumeInfo] = []
    var readBytesPerSec: Double = 0.0
    var writeBytesPerSec: Double = 0.0
    var totalReadBytes: UInt64 = 0
    var totalWriteBytes: UInt64 = 0

    static let empty = DiskMetrics()

    var formattedReadSpeed: String {
        ByteFormatter.formatSpeed(readBytesPerSec)
    }

    var formattedWriteSpeed: String {
        ByteFormatter.formatSpeed(writeBytesPerSec)
    }
}

struct VolumeInfo: Equatable, Identifiable {
    let id = UUID()
    var name: String
    var mountPoint: String
    var totalBytes: UInt64
    var usedBytes: UInt64
    var freeBytes: UInt64
    var fileSystem: String

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    var totalGB: Double { Double(totalBytes) / 1_073_741_824 }
    var usedGB: Double { Double(usedBytes) / 1_073_741_824 }
    var freeGB: Double { Double(freeBytes) / 1_073_741_824 }

    var statusColor: StatusColor {
        StatusColor.from(percentage: usagePercent)
    }
}

// MARK: - Status Color

enum StatusColor {
    case green
    case blue
    case yellow
    case red

    static func from(percentage: Double) -> StatusColor {
        switch percentage {
        case 0..<50: return .green
        case 50..<70: return .blue
        case 70..<90: return .yellow
        default: return .red
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .green: return .green
        case .blue: return .blue
        case .yellow: return .yellow
        case .red: return .red
        }
    }

    var description: String {
        switch self {
        case .green: return "Normal"
        case .blue: return "Moderate"
        case .yellow: return "High"
        case .red: return "Critical"
        }
    }
}

// MARK: - System Info

struct SystemInfo: Equatable {
    var modelName: String = "Unknown"
    var macOSVersion: String = "Unknown"
    var uptime: TimeInterval = 0
    var bootTime: Date = Date()

    static let empty = SystemInfo()

    var formattedUptime: String {
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
