//
//  ProcessMonitor.swift
//  Operator
//
//  Process monitoring using libproc APIs.
//

import Foundation
import Darwin

class ProcessMonitor {
    private var previousCPUTimes: [Int32: (user: UInt64, system: UInt64)] = [:]
    private var previousTimestamp: Date?

    func getTopProcesses(count: Int = 20, sortBy: ProcessSortKey = .cpu) -> [ProcessInfoModel] {
        var processes: [ProcessInfoModel] = []

        // Get all PIDs
        let bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(bufferSize) / MemoryLayout<pid_t>.size)
        let actualSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, bufferSize)

        guard actualSize > 0 else { return [] }

        let pidCount = Int(actualSize) / MemoryLayout<pid_t>.size
        let currentTime = Date()
        let timeDelta = previousTimestamp.map { currentTime.timeIntervalSince($0) } ?? 1.0

        let totalMemory = Double(Sysctl.physicalMemory)

        for i in 0..<pidCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            // Get process info
            var taskInfo = proc_taskallinfo()
            let taskInfoSize = MemoryLayout<proc_taskallinfo>.size

            let result = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &taskInfo, Int32(taskInfoSize))
            guard result == taskInfoSize else { continue }

            // Get process name - use MAXPATHLEN * 4 as the buffer size
            var pathBuffer = [CChar](repeating: 0, count: 4096)
            proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            let path = String(cString: pathBuffer)
            let name = (path as NSString).lastPathComponent

            // Skip if no name
            guard !name.isEmpty else { continue }

            // Calculate CPU usage from task times
            let userTime = UInt64(taskInfo.ptinfo.pti_total_user)
            let systemTime = UInt64(taskInfo.ptinfo.pti_total_system)
            var cpuUsage: Double = 0

            if let prev = previousCPUTimes[pid], timeDelta > 0 {
                let userDelta = userTime > prev.user ? userTime - prev.user : 0
                let systemDelta = systemTime > prev.system ? systemTime - prev.system : 0
                let totalDelta = Double(userDelta + systemDelta) / 1_000_000_000.0  // Convert from nanoseconds

                // CPU usage as percentage (can exceed 100% on multi-core)
                cpuUsage = (totalDelta / timeDelta) * 100
            }

            previousCPUTimes[pid] = (userTime, systemTime)

            // Memory usage
            let residentSize = UInt64(taskInfo.ptinfo.pti_resident_size)
            let memoryPercent = totalMemory > 0 ? (Double(residentSize) / totalMemory) * 100 : 0

            // Get username (simplified - would need proper UID lookup for full username)
            let uid = taskInfo.pbsd.pbi_uid
            let username = getUsername(for: uid)

            // Process state
            let state = getProcessState(from: taskInfo.pbsd.pbi_status)

            processes.append(ProcessInfoModel(
                id: pid,
                name: name,
                cpuUsage: cpuUsage,
                memoryUsage: memoryPercent,
                memoryBytes: residentSize,
                user: username,
                threads: taskInfo.ptinfo.pti_threadnum,
                state: state,
                path: path.isEmpty ? nil : path,
                bundleIdentifier: nil
            ))
        }

        previousTimestamp = currentTime

        // Sort processes
        switch sortBy {
        case .cpu:
            processes.sort { $0.cpuUsage > $1.cpuUsage }
        case .memory:
            processes.sort { $0.memoryUsage > $1.memoryUsage }
        case .name:
            processes.sort { $0.name.lowercased() < $1.name.lowercased() }
        case .pid:
            processes.sort { $0.id < $1.id }
        }

        // Return top N
        return Array(processes.prefix(count))
    }

    // MARK: - Private Methods

    private func getUsername(for uid: UInt32) -> String {
        // Get username from UID
        if let passwd = getpwuid(uid) {
            return String(cString: passwd.pointee.pw_name)
        }
        return String(uid)
    }

    private func getProcessState(from status: UInt32) -> ProcessState {
        // SIDL = 1, SRUN = 2, SSLEEP = 3, SSTOP = 4, SZOMB = 5
        switch status {
        case 2:
            return .running
        case 3:
            return .sleeping
        case 4:
            return .stopped
        case 5:
            return .zombie
        default:
            return .unknown
        }
    }

    /// Clean up stale process entries
    func cleanupStaleProcesses() {
        // Remove entries for processes that no longer exist
        var pids = [pid_t](repeating: 0, count: 4096)
        let size = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(pids.count * MemoryLayout<pid_t>.size))

        if size > 0 {
            let activePids = Set(pids.prefix(Int(size) / MemoryLayout<pid_t>.size))
            previousCPUTimes = previousCPUTimes.filter { activePids.contains($0.key) }
        }
    }
}
