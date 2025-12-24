//
//  MachHelpers.swift
//  Operator
//
//  Mach API helpers for CPU and memory statistics.
//

import Foundation
import Darwin

enum MachHelpers {
    // MARK: - CPU Statistics

    /// CPU tick counts for each state
    struct CPUTicks {
        var user: UInt64 = 0
        var system: UInt64 = 0
        var idle: UInt64 = 0
        var nice: UInt64 = 0

        var total: UInt64 { user + system + idle + nice }
    }

    /// Get CPU usage for all cores
    static func getCPUUsage() -> (total: Double, perCore: [Double])? {
        var cpuInfo: processor_info_array_t?
        var numCPUs: mach_msg_type_number_t = 0
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return nil
        }

        defer {
            let cpuInfoSize = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), cpuInfoSize)
        }

        var coreUsages: [Double] = []
        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = UInt64(cpuInfo[offset + Int(CPU_STATE_USER)])
            let system = UInt64(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt64(cpuInfo[offset + Int(CPU_STATE_NICE)])

            let total = user + system + idle + nice
            let usage = total > 0 ? Double(user + system + nice) / Double(total) * 100 : 0
            coreUsages.append(usage)

            totalUser += user + nice
            totalSystem += system
            totalIdle += idle
        }

        let grandTotal = totalUser + totalSystem + totalIdle
        let totalUsage = grandTotal > 0 ? Double(totalUser + totalSystem) / Double(grandTotal) * 100 : 0

        return (totalUsage, coreUsages)
    }

    // MARK: - Memory Statistics

    /// Get memory statistics using vm_statistics64
    static func getMemoryStats() -> (used: UInt64, free: UInt64, active: UInt64, inactive: UInt64, wired: UInt64, compressed: UInt64)? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize

        // Used = active + inactive + wired + compressed
        let used = active + inactive + wired + compressed

        return (used, free, active, inactive, wired, compressed)
    }

    /// Get swap usage
    static func getSwapUsage() -> (total: UInt64, used: UInt64)? {
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size

        guard sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0) == 0 else {
            return nil
        }

        return (swapUsage.xsu_total, swapUsage.xsu_used)
    }
}

// MARK: - Network Interface Helpers

enum NetworkHelpers {
    /// Get network interface statistics using getifaddrs
    static func getInterfaceStats() -> [String: (bytesSent: UInt64, bytesReceived: UInt64, isUp: Bool, ipAddress: String?)] {
        var result: [String: (UInt64, UInt64, Bool, String?)] = [:]
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddrs) == 0, let firstAddr = ifaddrs else {
            return result
        }

        defer { freeifaddrs(ifaddrs) }

        var current: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = current {
            guard let ifaAddr = addr.pointee.ifa_addr else {
                current = addr.pointee.ifa_next
                continue
            }

            let name = String(cString: addr.pointee.ifa_name)

            // Get IP address for AF_INET
            if ifaAddr.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(ifaAddr, socklen_t(ifaAddr.pointee.sa_len),
                              &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(cString: hostname)
                    if var existing = result[name] {
                        existing.3 = ip
                        result[name] = existing
                    } else {
                        result[name] = (0, 0, false, ip)
                    }
                }
            }

            // Get traffic stats for AF_LINK
            if ifaAddr.pointee.sa_family == UInt8(AF_LINK) {
                if let data = addr.pointee.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    let isUp = (addr.pointee.ifa_flags & UInt32(IFF_UP)) != 0

                    if var existing = result[name] {
                        existing.0 = UInt64(networkData.ifi_obytes)
                        existing.1 = UInt64(networkData.ifi_ibytes)
                        existing.2 = isUp
                        result[name] = existing
                    } else {
                        result[name] = (UInt64(networkData.ifi_obytes), UInt64(networkData.ifi_ibytes), isUp, nil)
                    }
                }
            }

            current = addr.pointee.ifa_next
        }

        return result
    }
}
