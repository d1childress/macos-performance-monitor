//
//  HistoryStore.swift
//  Operator
//
//  Persists historical metrics data for trends, session reports, and anomaly detection.
//

import Foundation
import Combine

/// A data point representing system metrics at a specific time
struct MetricDataPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let memoryBytes: UInt64
    let networkUpload: Double
    let networkDownload: Double
    let diskRead: Double
    let diskWrite: Double

    init(
        timestamp: Date = Date(),
        cpuUsage: Double,
        memoryUsage: Double,
        memoryBytes: UInt64,
        networkUpload: Double,
        networkDownload: Double,
        diskRead: Double,
        diskWrite: Double
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.memoryBytes = memoryBytes
        self.networkUpload = networkUpload
        self.networkDownload = networkDownload
        self.diskRead = diskRead
        self.diskWrite = diskWrite
    }
}

/// Session summary for session reports
struct SessionSummary: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let avgCPU: Double
    let maxCPU: Double
    let avgMemory: Double
    let maxMemory: Double
    let totalNetworkUpload: UInt64
    let totalNetworkDownload: UInt64
    let totalDiskRead: UInt64
    let totalDiskWrite: UInt64
    let alertCount: Int
    let topProcesses: [String]

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

/// Time range for querying historical data
enum TimeRange: String, CaseIterable, Identifiable {
    case lastHour = "Last Hour"
    case last6Hours = "Last 6 Hours"
    case last24Hours = "Last 24 Hours"
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case custom = "Custom"

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .lastHour: return 3600
        case .last6Hours: return 3600 * 6
        case .last24Hours: return 3600 * 24
        case .last7Days: return 3600 * 24 * 7
        case .last30Days: return 3600 * 24 * 30
        case .custom: return 0
        }
    }
}

/// Manages persistent storage of metrics history
@MainActor
class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    // MARK: - Published Properties

    @Published private(set) var dataPoints: [MetricDataPoint] = []
    @Published private(set) var sessions: [SessionSummary] = []
    @Published private(set) var isRecording = false

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var currentSessionStart: Date?
    private var sessionDataPoints: [MetricDataPoint] = []
    private var saveTimer: Timer?

    // Storage limits
    private let maxDataPoints = 86400 // ~24 hours at 1s intervals
    private let maxSessions = 100
    private let saveInterval: TimeInterval = 60 // Save every minute

    // MARK: - Initialization

    private init() {
        loadData()
        startAutoSave()
    }

    deinit {
        saveTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Record a new data point
    func record(
        cpuUsage: Double,
        memoryUsage: Double,
        memoryBytes: UInt64,
        networkUpload: Double,
        networkDownload: Double,
        diskRead: Double,
        diskWrite: Double
    ) {
        let dataPoint = MetricDataPoint(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            memoryBytes: memoryBytes,
            networkUpload: networkUpload,
            networkDownload: networkDownload,
            diskRead: diskRead,
            diskWrite: diskWrite
        )

        dataPoints.append(dataPoint)

        // Trim old data
        if dataPoints.count > maxDataPoints {
            dataPoints.removeFirst(dataPoints.count - maxDataPoints)
        }

        // Track session data
        if isRecording {
            sessionDataPoints.append(dataPoint)
        }
    }

    /// Start recording a new session
    func startSession() {
        currentSessionStart = Date()
        sessionDataPoints = []
        isRecording = true
    }

    /// End the current session and save summary
    func endSession(alertCount: Int = 0, topProcesses: [String] = []) {
        guard let startTime = currentSessionStart, !sessionDataPoints.isEmpty else {
            isRecording = false
            return
        }

        let summary = createSessionSummary(
            startTime: startTime,
            endTime: Date(),
            dataPoints: sessionDataPoints,
            alertCount: alertCount,
            topProcesses: topProcesses
        )

        sessions.append(summary)

        // Trim old sessions
        if sessions.count > maxSessions {
            sessions.removeFirst(sessions.count - maxSessions)
        }

        // Reset
        currentSessionStart = nil
        sessionDataPoints = []
        isRecording = false

        saveData()
    }

    /// Get data points within a time range
    func getData(for range: TimeRange, customStart: Date? = nil, customEnd: Date? = nil) -> [MetricDataPoint] {
        let now = Date()
        let startDate: Date
        let endDate: Date

        if range == .custom, let start = customStart, let end = customEnd {
            startDate = start
            endDate = end
        } else {
            startDate = now.addingTimeInterval(-range.seconds)
            endDate = now
        }

        return dataPoints.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Get aggregated data for charts (reduces data points for performance)
    func getAggregatedData(for range: TimeRange, maxPoints: Int = 100) -> [MetricDataPoint] {
        let data = getData(for: range)

        guard data.count > maxPoints else { return data }

        let bucketSize = data.count / maxPoints
        var aggregated: [MetricDataPoint] = []

        for i in stride(from: 0, to: data.count, by: bucketSize) {
            let bucket = Array(data[i..<min(i + bucketSize, data.count)])
            if let first = bucket.first {
                let avgCPU = bucket.map(\.cpuUsage).reduce(0, +) / Double(bucket.count)
                let avgMemory = bucket.map(\.memoryUsage).reduce(0, +) / Double(bucket.count)
                let avgMemBytes = bucket.map(\.memoryBytes).reduce(0, +) / UInt64(bucket.count)
                let avgUpload = bucket.map(\.networkUpload).reduce(0, +) / Double(bucket.count)
                let avgDownload = bucket.map(\.networkDownload).reduce(0, +) / Double(bucket.count)
                let avgDiskRead = bucket.map(\.diskRead).reduce(0, +) / Double(bucket.count)
                let avgDiskWrite = bucket.map(\.diskWrite).reduce(0, +) / Double(bucket.count)

                aggregated.append(MetricDataPoint(
                    timestamp: first.timestamp,
                    cpuUsage: avgCPU,
                    memoryUsage: avgMemory,
                    memoryBytes: avgMemBytes,
                    networkUpload: avgUpload,
                    networkDownload: avgDownload,
                    diskRead: avgDiskRead,
                    diskWrite: avgDiskWrite
                ))
            }
        }

        return aggregated
    }

    /// Export data to JSON
    func exportToJSON(range: TimeRange) -> Data? {
        let data = getData(for: range)
        return try? encoder.encode(data)
    }

    /// Export data to CSV
    func exportToCSV(range: TimeRange) -> String {
        let data = getData(for: range)
        var csv = "Timestamp,CPU %,Memory %,Memory Bytes,Upload B/s,Download B/s,Disk Read B/s,Disk Write B/s\n"

        let dateFormatter = ISO8601DateFormatter()

        for point in data {
            csv += "\(dateFormatter.string(from: point.timestamp)),"
            csv += "\(point.cpuUsage),"
            csv += "\(point.memoryUsage),"
            csv += "\(point.memoryBytes),"
            csv += "\(point.networkUpload),"
            csv += "\(point.networkDownload),"
            csv += "\(point.diskRead),"
            csv += "\(point.diskWrite)\n"
        }

        return csv
    }

    /// Clear all historical data
    func clearHistory() {
        dataPoints = []
        sessions = []
        saveData()
    }

    // MARK: - Private Methods

    private func createSessionSummary(
        startTime: Date,
        endTime: Date,
        dataPoints: [MetricDataPoint],
        alertCount: Int,
        topProcesses: [String]
    ) -> SessionSummary {
        let cpuValues = dataPoints.map(\.cpuUsage)
        let memValues = dataPoints.map(\.memoryUsage)

        return SessionSummary(
            id: UUID(),
            startTime: startTime,
            endTime: endTime,
            avgCPU: cpuValues.isEmpty ? 0 : cpuValues.reduce(0, +) / Double(cpuValues.count),
            maxCPU: cpuValues.max() ?? 0,
            avgMemory: memValues.isEmpty ? 0 : memValues.reduce(0, +) / Double(memValues.count),
            maxMemory: memValues.max() ?? 0,
            totalNetworkUpload: UInt64(dataPoints.map(\.networkUpload).reduce(0, +)),
            totalNetworkDownload: UInt64(dataPoints.map(\.networkDownload).reduce(0, +)),
            totalDiskRead: UInt64(dataPoints.map(\.diskRead).reduce(0, +)),
            totalDiskWrite: UInt64(dataPoints.map(\.diskWrite).reduce(0, +)),
            alertCount: alertCount,
            topProcesses: topProcesses
        )
    }

    private var dataURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let operatorDir = appSupport.appendingPathComponent("Operator", isDirectory: true)

        try? fileManager.createDirectory(at: operatorDir, withIntermediateDirectories: true)

        return operatorDir.appendingPathComponent("history.json")
    }

    private var sessionsURL: URL {
        dataURL.deletingLastPathComponent().appendingPathComponent("sessions.json")
    }

    private func loadData() {
        // Load data points
        if let data = try? Data(contentsOf: dataURL),
           let points = try? decoder.decode([MetricDataPoint].self, from: data) {
            // Only keep recent data (last 24 hours)
            let cutoff = Date().addingTimeInterval(-86400)
            dataPoints = points.filter { $0.timestamp > cutoff }
        }

        // Load sessions
        if let data = try? Data(contentsOf: sessionsURL),
           let loadedSessions = try? decoder.decode([SessionSummary].self, from: data) {
            sessions = loadedSessions
        }
    }

    private func saveData() {
        // Save data points
        if let data = try? encoder.encode(dataPoints) {
            try? data.write(to: dataURL)
        }

        // Save sessions
        if let data = try? encoder.encode(sessions) {
            try? data.write(to: sessionsURL)
        }
    }

    private func startAutoSave() {
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.saveData()
            }
        }
    }
}
