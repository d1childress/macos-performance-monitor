//
//  SysctlWrapper.swift
//  Operator
//
//  Swift wrapper for sysctl system calls.
//

import Foundation
import Darwin

enum Sysctl {
    /// Get string value from sysctl
    static func string(for keys: [Int32]) -> String? {
        var size: size_t = 0
        var mib = keys

        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0 else {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0 else {
            return nil
        }

        return String(cString: buffer)
    }

    /// Get string value from sysctl by name
    static func string(for name: String) -> String? {
        var size: size_t = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }

        return String(cString: buffer)
    }

    /// Get integer value from sysctl by name
    static func int32(for name: String) -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

    /// Get 64-bit integer value from sysctl by name
    static func int64(for name: String) -> Int64? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

    /// Get unsigned 64-bit integer value from sysctl by name
    static func uint64(for name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

    // MARK: - Common System Values

    /// Physical CPU core count
    static var physicalCPUCount: Int32 {
        int32(for: "hw.physicalcpu") ?? 1
    }

    /// Logical CPU (thread) count
    static var logicalCPUCount: Int32 {
        int32(for: "hw.logicalcpu") ?? 1
    }

    /// Total physical memory in bytes
    static var physicalMemory: UInt64 {
        uint64(for: "hw.memsize") ?? 0
    }

    /// Machine model identifier (e.g., "MacBookPro18,1")
    static var machineModel: String {
        string(for: "hw.model") ?? "Unknown"
    }

    /// CPU brand string
    static var cpuBrand: String {
        string(for: "machdep.cpu.brand_string") ?? "Apple Silicon"
    }

    /// System boot time
    static var bootTime: Date {
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size

        guard sysctl(&mib, UInt32(mib.count), &boottime, &size, nil, 0) == 0 else {
            return Date()
        }

        return Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec))
    }

    /// System uptime in seconds
    static var uptime: TimeInterval {
        Date().timeIntervalSince(bootTime)
    }

    /// macOS version string
    static var osVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    /// Page size in bytes
    static var pageSize: UInt64 {
        UInt64(vm_page_size)
    }
}
