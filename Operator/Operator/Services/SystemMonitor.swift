//
//  SystemMonitor.swift
//  Operator
//
//  Main coordinator for all system monitoring services.
//

import Foundation
import Combine
import Network

@MainActor
class SystemMonitor: ObservableObject {
    // MARK: - Published Metrics

    @Published var cpuMetrics = CPUMetrics.empty
    @Published var memoryMetrics = MemoryMetrics.empty
    @Published var networkMetrics = NetworkMetrics.empty
    @Published var diskMetrics = DiskMetrics.empty
    @Published var systemInfo = SystemInfo.empty
    @Published var processes: [ProcessInfoModel] = []
    @Published var batteryMetrics = BatteryMetrics.empty
    @Published var thermalMetrics = ThermalMetrics.empty

    // MARK: - Settings

    @Published var refreshInterval: TimeInterval = 1.0 {
        didSet {
            restartTimer()
        }
    }

    @Published var historyLength: Int = 60  // Keep 60 data points

    // MARK: - Private Properties

    private var timer: Timer?
    private let collector = MetricsCollector()
    private var lastProcessRefresh: Date = .distantPast
    private let processRefreshInterval: TimeInterval = 2.0
    private var lastBatteryRefresh: Date = .distantPast
    private let batteryRefreshInterval: TimeInterval = 5.0

    // MARK: - Initialization

    init() {
        loadSystemInfo()
        startMonitoring()
        HistoryStore.shared.startSession()
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Public Methods

    func startMonitoring() {
        stopMonitoring()
        Task {
            await collector.startPathMonitor()
        }

        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refreshMetrics()
        }
        timer?.tolerance = 0.1

        // Initial update
        refreshMetrics()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        Task {
            await collector.stopPathMonitor()
        }
    }

    func forceRefresh() {
        refreshMetrics()
    }

    // MARK: - Private Methods

    private func restartTimer() {
        startMonitoring()
    }

    private func loadSystemInfo() {
        systemInfo = SystemInfo(
            modelName: Sysctl.machineModel,
            macOSVersion: Sysctl.osVersion,
            uptime: Sysctl.uptime,
            bootTime: Sysctl.bootTime
        )
    }

    private func refreshMetrics() {
        let includeProcesses = shouldRefreshProcesses
        let includeBattery = shouldRefreshBattery
        let historyLimit = historyLength
        let currentCPUHistory = cpuMetrics.history
        let currentMemoryHistory = memoryMetrics.history
        let currentUploadHistory = networkMetrics.uploadHistory
        let currentDownloadHistory = networkMetrics.downloadHistory
        let currentBatteryHistory = batteryMetrics.history
        let currentCPUTempHistory = thermalMetrics.cpuHistory
        let currentGPUTempHistory = thermalMetrics.gpuHistory
        let collector = self.collector

        Task.detached { [weak self, collector] in
            let snapshot = await collector.collect(
                includeProcesses: includeProcesses,
                includeBattery: includeBattery,
                processCount: 50
            )

            await MainActor.run {
                guard let self else { return }

                // CPU
                var cpu = snapshot.cpu
                cpu.history = Self.updateHistory(currentCPUHistory, with: cpu.totalUsage, maxCount: historyLimit)
                self.cpuMetrics = cpu

                // Memory
                var memory = snapshot.memory
                memory.history = Self.updateHistory(currentMemoryHistory, with: memory.usagePercent, maxCount: historyLimit)
                self.memoryMetrics = memory

                // Network
                var network = snapshot.network
                network.uploadHistory = Self.updateHistory(currentUploadHistory, with: network.uploadSpeed, maxCount: historyLimit)
                network.downloadHistory = Self.updateHistory(currentDownloadHistory, with: network.downloadSpeed, maxCount: historyLimit)
                self.networkMetrics = network

                // Disk
                self.diskMetrics = snapshot.disk

                // System Info (uptime changes)
                self.systemInfo.uptime = Sysctl.uptime

                // Processes (throttled)
                if includeProcesses, let processList = snapshot.processes {
                    self.processes = processList
                    self.lastProcessRefresh = Date()
                }

                // Battery & Thermal (throttled)
                if includeBattery {
                    var battery = snapshot.battery
                    battery.history = Self.updateHistory(currentBatteryHistory, with: battery.chargePercent, maxCount: historyLimit)
                    self.batteryMetrics = battery

                    var thermal = snapshot.thermal
                    thermal.cpuHistory = Self.updateHistory(currentCPUTempHistory, with: thermal.cpuTemperature, maxCount: historyLimit)
                    thermal.gpuHistory = Self.updateHistory(currentGPUTempHistory, with: thermal.gpuTemperature, maxCount: historyLimit)
                    self.thermalMetrics = thermal

                    self.lastBatteryRefresh = Date()
                }

                // Record to history store
                HistoryStore.shared.record(
                    cpuUsage: cpu.totalUsage,
                    memoryUsage: memory.usagePercent,
                    memoryBytes: memory.usedBytes,
                    networkUpload: network.uploadSpeed,
                    networkDownload: network.downloadSpeed,
                    diskRead: self.diskMetrics.readBytesPerSec,
                    diskWrite: self.diskMetrics.writeBytesPerSec
                )

                // Check alerts
                let diskFreePercent: Double
                if let firstVolume = self.diskMetrics.volumes.first {
                    diskFreePercent = 100 - firstVolume.usagePercent
                } else {
                    diskFreePercent = 100
                }
                AlertManager.shared.checkMetrics(
                    cpuUsage: cpu.totalUsage,
                    memoryUsage: memory.usagePercent,
                    isNetworkConnected: network.isConnected,
                    uploadSpeed: network.uploadSpeed,
                    downloadSpeed: network.downloadSpeed,
                    diskFreePercent: diskFreePercent,
                    topProcesses: self.processes
                )
            }
        }
    }

    private var shouldRefreshBattery: Bool {
        Date().timeIntervalSince(lastBatteryRefresh) >= batteryRefreshInterval
    }

    private var shouldRefreshProcesses: Bool {
        Date().timeIntervalSince(lastProcessRefresh) >= processRefreshInterval
    }

    private static func updateHistory(_ history: [Double], with value: Double, maxCount: Int) -> [Double] {
        var newHistory = history
        newHistory.append(value)
        if newHistory.count > maxCount {
            newHistory.removeFirst(newHistory.count - maxCount)
        }
        return newHistory
    }
}

// MARK: - Metrics Collector

private actor MetricsCollector {
    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let networkMonitor = NetworkMonitor()
    private let diskMonitor = DiskMonitor()
    private let processMonitor = ProcessMonitor()
    private let batteryMonitor = BatteryMonitor()

    func startPathMonitor() {
        networkMonitor.startPathMonitor()
    }

    func stopPathMonitor() {
        networkMonitor.stopPathMonitor()
    }

    func collect(includeProcesses: Bool, includeBattery: Bool, processCount: Int) async -> MetricsSnapshot {
        let cpu = cpuMonitor.getMetrics()
        let memory = memoryMonitor.getMetrics()
        let network = networkMonitor.getMetrics()
        let disk = diskMonitor.getMetrics()

        let processes: [ProcessInfoModel]? = includeProcesses
        ? processMonitor.getTopProcesses(count: processCount)
        : nil

        if includeProcesses {
            processMonitor.cleanupStaleProcesses()
        }

        let battery: BatteryMetrics
        let thermal: ThermalMetrics
        if includeBattery {
            battery = batteryMonitor.getMetrics()
            thermal = batteryMonitor.getThermalMetrics()
        } else {
            battery = .empty
            thermal = .empty
        }

        return MetricsSnapshot(
            cpu: cpu,
            memory: memory,
            network: network,
            disk: disk,
            processes: processes,
            battery: battery,
            thermal: thermal
        )
    }
}

private struct MetricsSnapshot {
    let cpu: CPUMetrics
    let memory: MemoryMetrics
    let network: NetworkMetrics
    let disk: DiskMetrics
    let processes: [ProcessInfoModel]?
    let battery: BatteryMetrics
    let thermal: ThermalMetrics
}
