//
//  ProcessInfo.swift
//  Operator
//
//  Process data model for system processes.
//

import Foundation

struct ProcessInfoModel: Identifiable, Equatable {
    let id: Int32  // PID
    var name: String
    var cpuUsage: Double
    var memoryUsage: Double  // Percentage
    var memoryBytes: UInt64
    var user: String
    var threads: Int32
    var state: ProcessState
    var path: String?  // Full path to executable
    var bundleIdentifier: String?  // Bundle ID for apps

    static func == (lhs: ProcessInfoModel, rhs: ProcessInfoModel) -> Bool {
        lhs.id == rhs.id
    }

    var formattedMemory: String {
        ByteFormatter.formatBytes(memoryBytes)
    }

    var cpuStatusColor: StatusColor {
        StatusColor.from(percentage: cpuUsage)
    }

    var memoryStatusColor: StatusColor {
        StatusColor.from(percentage: memoryUsage)
    }

    /// Check if process is a macOS app bundle
    var isApp: Bool {
        path?.contains(".app/") ?? false
    }

    /// Get the app bundle path if available
    var appBundlePath: String? {
        guard let path = path, let range = path.range(of: ".app/") else { return nil }
        return String(path[..<range.upperBound]).dropLast().description
    }
}

enum ProcessState: String {
    case running = "Running"
    case sleeping = "Sleeping"
    case stopped = "Stopped"
    case zombie = "Zombie"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .running: return "play.circle.fill"
        case .sleeping: return "moon.circle.fill"
        case .stopped: return "pause.circle.fill"
        case .zombie: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

enum ProcessSortKey: String, CaseIterable {
    case cpu = "CPU"
    case memory = "Memory"
    case name = "Name"
    case pid = "PID"

    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .name: return "textformat"
        case .pid: return "number"
        }
    }
}
