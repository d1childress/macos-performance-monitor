//
//  CPUMonitor.swift
//  Operator
//
//  CPU monitoring using Mach APIs.
//

import Foundation
import Darwin

class CPUMonitor {
    // Store previous CPU ticks for delta calculation
    private var previousTicks: [MachHelpers.CPUTicks] = []
    private var previousTotalTicks = MachHelpers.CPUTicks()

    init() {
        // Prime the CPU readings
        _ = getRawCPUTicks()
    }

    func getMetrics() -> CPUMetrics {
        let coreCount = Int(Sysctl.physicalCPUCount)
        let threadCount = Int(Sysctl.logicalCPUCount)

        guard let (totalUsage, coreUsages) = calculateCPUUsage() else {
            return CPUMetrics(
                coreCount: coreCount,
                threadCount: threadCount
            )
        }

        return CPUMetrics(
            totalUsage: totalUsage,
            userUsage: 0,  // Could be calculated from raw ticks
            systemUsage: 0,
            idleUsage: 100 - totalUsage,
            coreUsages: coreUsages,
            coreCount: coreCount,
            threadCount: threadCount,
            frequency: nil  // Not available on Apple Silicon
        )
    }

    // MARK: - Private Methods

    private func calculateCPUUsage() -> (total: Double, perCore: [Double])? {
        guard let currentTicks = getRawCPUTicks() else { return nil }

        // If we don't have previous data, store current and return nil
        if previousTicks.isEmpty {
            previousTicks = currentTicks.perCore
            previousTotalTicks = currentTicks.total
            return nil
        }

        // Calculate per-core usage from delta
        var coreUsages: [Double] = []
        for (index, current) in currentTicks.perCore.enumerated() {
            guard index < previousTicks.count else { continue }

            let prev = previousTicks[index]
            let totalDelta = current.total - prev.total
            let idleDelta = current.idle - prev.idle

            if totalDelta > 0 {
                let usage = Double(totalDelta - idleDelta) / Double(totalDelta) * 100
                coreUsages.append(max(0, min(100, usage)))
            } else {
                coreUsages.append(0)
            }
        }

        // Calculate total usage from delta
        let totalDelta = currentTicks.total.total - previousTotalTicks.total
        let idleDelta = currentTicks.total.idle - previousTotalTicks.idle
        let totalUsage: Double

        if totalDelta > 0 {
            totalUsage = Double(totalDelta - idleDelta) / Double(totalDelta) * 100
        } else {
            totalUsage = 0
        }

        // Store current as previous for next calculation
        previousTicks = currentTicks.perCore
        previousTotalTicks = currentTicks.total

        return (max(0, min(100, totalUsage)), coreUsages)
    }

    private func getRawCPUTicks() -> (total: MachHelpers.CPUTicks, perCore: [MachHelpers.CPUTicks])? {
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

        var perCoreTicks: [MachHelpers.CPUTicks] = []
        var totalTicks = MachHelpers.CPUTicks()

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i

            var ticks = MachHelpers.CPUTicks()
            ticks.user = UInt64(cpuInfo[offset + Int(CPU_STATE_USER)])
            ticks.system = UInt64(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            ticks.idle = UInt64(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            ticks.nice = UInt64(cpuInfo[offset + Int(CPU_STATE_NICE)])

            perCoreTicks.append(ticks)

            totalTicks.user += ticks.user
            totalTicks.system += ticks.system
            totalTicks.idle += ticks.idle
            totalTicks.nice += ticks.nice
        }

        return (totalTicks, perCoreTicks)
    }
}
