//
//  Formatters.swift
//  Operator
//
//  Utility formatters for bytes, rates, and percentages.
//

import Foundation

enum ByteFormatter {
    /// Format bytes to human-readable string (KB, MB, GB, etc.)
    static func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else if value < 10 {
            return String(format: "%.2f %@", value, units[unitIndex])
        } else if value < 100 {
            return String(format: "%.1f %@", value, units[unitIndex])
        } else {
            return String(format: "%.0f %@", value, units[unitIndex])
        }
    }

    /// Format bytes per second to human-readable speed
    static func formatSpeed(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if value < 10 {
            return String(format: "%.1f %@", value, units[unitIndex])
        } else {
            return String(format: "%.0f %@", value, units[unitIndex])
        }
    }

    /// Format bytes per second to compact string for menu bar
    static func formatSpeedCompact(_ bytesPerSecond: Double) -> String {
        let units = ["B", "K", "M", "G"]
        var value = bytesPerSecond
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if value < 10 {
            return String(format: "%.1f%@", value, units[unitIndex])
        } else {
            return String(format: "%.0f%@", value, units[unitIndex])
        }
    }
}

enum PercentFormatter {
    /// Format percentage with specified decimal places
    static func format(_ value: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f%%", value)
    }

    /// Format percentage as integer
    static func formatInt(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }
}

enum TimeFormatter {
    /// Format seconds to HH:MM:SS
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    /// Format uptime in days, hours, minutes
    static func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        var components: [String] = []
        if days > 0 { components.append("\(days)d") }
        if hours > 0 { components.append("\(hours)h") }
        if minutes > 0 || components.isEmpty { components.append("\(minutes)m") }

        return components.joined(separator: " ")
    }
}
