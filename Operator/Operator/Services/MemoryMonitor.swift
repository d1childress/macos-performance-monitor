//
//  MemoryMonitor.swift
//  Operator
//
//  Memory monitoring using Mach vm_statistics64 API.
//

import Foundation
import Darwin

class MemoryMonitor {

    func getMetrics() -> MemoryMetrics {
        let totalMemory = Sysctl.physicalMemory

        guard let stats = MachHelpers.getMemoryStats() else {
            return MemoryMetrics(totalBytes: totalMemory)
        }

        let swap = MachHelpers.getSwapUsage()

        return MemoryMetrics(
            totalBytes: totalMemory,
            usedBytes: stats.used,
            freeBytes: stats.free,
            activeBytes: stats.active,
            inactiveBytes: stats.inactive,
            wiredBytes: stats.wired,
            compressedBytes: stats.compressed,
            swapTotalBytes: swap?.total ?? 0,
            swapUsedBytes: swap?.used ?? 0
        )
    }

    /// Get detailed memory breakdown for display
    func getDetailedBreakdown() -> [(label: String, bytes: UInt64, color: String)] {
        guard let stats = MachHelpers.getMemoryStats() else { return [] }

        return [
            ("Active", stats.active, "blue"),
            ("Inactive", stats.inactive, "cyan"),
            ("Wired", stats.wired, "orange"),
            ("Compressed", stats.compressed, "purple"),
            ("Free", stats.free, "green")
        ]
    }
}
