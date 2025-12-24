//
//  AlertManager.swift
//  Operator
//
//  Manages alert rules and macOS notifications for system metrics.
//

import Foundation
import UserNotifications
import Combine

/// Types of alerts that can be configured
enum AlertType: String, Codable, CaseIterable, Identifiable {
    case cpuHigh = "High CPU Usage"
    case cpuSustained = "Sustained CPU Usage"
    case memoryHigh = "High Memory Usage"
    case memoryPressure = "Memory Pressure"
    case networkDisconnected = "Network Disconnected"
    case networkHighUpload = "High Upload Speed"
    case networkHighDownload = "High Download Speed"
    case diskSpaceLow = "Low Disk Space"
    case processHighCPU = "Process High CPU"
    case processHighMemory = "Process High Memory"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cpuHigh, .cpuSustained: return "cpu"
        case .memoryHigh, .memoryPressure: return "memorychip"
        case .networkDisconnected, .networkHighUpload, .networkHighDownload: return "network"
        case .diskSpaceLow: return "internaldrive"
        case .processHighCPU, .processHighMemory: return "gearshape.2"
        }
    }

    var defaultThreshold: Double {
        switch self {
        case .cpuHigh: return 90
        case .cpuSustained: return 80
        case .memoryHigh: return 90
        case .memoryPressure: return 85
        case .networkDisconnected: return 0
        case .networkHighUpload: return 100_000_000 // 100 MB/s
        case .networkHighDownload: return 100_000_000
        case .diskSpaceLow: return 10 // 10% free
        case .processHighCPU: return 100
        case .processHighMemory: return 50
        }
    }
}

/// A configured alert rule
struct AlertRule: Codable, Identifiable, Equatable {
    let id: UUID
    var type: AlertType
    var threshold: Double
    var isEnabled: Bool
    var cooldownSeconds: TimeInterval
    var processName: String? // For process-specific alerts

    init(
        type: AlertType,
        threshold: Double? = nil,
        isEnabled: Bool = true,
        cooldownSeconds: TimeInterval = 60,
        processName: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.threshold = threshold ?? type.defaultThreshold
        self.isEnabled = isEnabled
        self.cooldownSeconds = cooldownSeconds
        self.processName = processName
    }
}

/// A triggered alert event
struct AlertEvent: Codable, Identifiable {
    let id: UUID
    let ruleId: UUID
    let type: AlertType
    let timestamp: Date
    let value: Double
    let threshold: Double
    let message: String
    var isRead: Bool

    init(rule: AlertRule, value: Double, message: String) {
        self.id = UUID()
        self.ruleId = rule.id
        self.type = rule.type
        self.timestamp = Date()
        self.value = value
        self.threshold = rule.threshold
        self.message = message
        self.isRead = false
    }
}

/// Manages alert rules and notifications
@MainActor
class AlertManager: ObservableObject {
    static let shared = AlertManager()

    // MARK: - Published Properties

    @Published var rules: [AlertRule] = []
    @Published var events: [AlertEvent] = []
    @Published var unreadCount: Int = 0

    // MARK: - Private Properties
    private var notificationsAvailable = false
    private var _notificationCenter: UNUserNotificationCenter?
    private var lastAlertTimes: [UUID: Date] = [:]
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // Anomaly detection state
    private var cpuHistory: [Double] = []
    private var memoryHistory: [Double] = []
    private let historySize = 60 // Keep 60 samples for anomaly detection

    // MARK: - Initialization

    private init() {
        loadRules()
        loadEvents()
        setupNotifications()
        setupDefaultRules()
    }

    // MARK: - Private Setup

    private func setupNotifications() {
        // Only try to use notifications if we have a proper app bundle
        guard Bundle.main.bundleIdentifier != nil else {
            print("AlertManager: No bundle identifier, notifications disabled")
            return
        }

        // Try to access the notification center - this may fail without a proper bundle
        _notificationCenter = UNUserNotificationCenter.current()

        if _notificationCenter != nil {
            notificationsAvailable = true
            requestNotificationPermission()
        }
    }

    // MARK: - Public Methods

    /// Request notification permissions
    func requestNotificationPermission() {
        guard notificationsAvailable, let center = _notificationCenter else { return }

        center.requestAuthorization(options: [.alert, .sound, .badge] as UNAuthorizationOptions) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    /// Add a new alert rule
    func addRule(_ rule: AlertRule) {
        rules.append(rule)
        saveRules()
    }

    /// Update an existing rule
    func updateRule(_ rule: AlertRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            saveRules()
        }
    }

    /// Delete a rule
    func deleteRule(_ rule: AlertRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
    }

    /// Check metrics against all enabled rules
    func checkMetrics(
        cpuUsage: Double,
        memoryUsage: Double,
        isNetworkConnected: Bool,
        uploadSpeed: Double,
        downloadSpeed: Double,
        diskFreePercent: Double,
        topProcesses: [ProcessInfoModel]
    ) {
        // Update history for anomaly detection
        updateHistory(cpu: cpuUsage, memory: memoryUsage)

        for rule in rules where rule.isEnabled {
            // Check cooldown
            if let lastTime = lastAlertTimes[rule.id],
               Date().timeIntervalSince(lastTime) < rule.cooldownSeconds {
                continue
            }

            var shouldAlert = false
            var value: Double = 0
            var message = ""

            switch rule.type {
            case .cpuHigh:
                if cpuUsage >= rule.threshold {
                    shouldAlert = true
                    value = cpuUsage
                    message = "CPU usage is at \(Int(cpuUsage))%, above threshold of \(Int(rule.threshold))%"
                }

            case .cpuSustained:
                if cpuHistory.count >= 30 {
                    let avg = cpuHistory.suffix(30).reduce(0, +) / 30
                    if avg >= rule.threshold {
                        shouldAlert = true
                        value = avg
                        message = "CPU has been above \(Int(rule.threshold))% for the last 30 seconds"
                    }
                }

            case .memoryHigh:
                if memoryUsage >= rule.threshold {
                    shouldAlert = true
                    value = memoryUsage
                    message = "Memory usage is at \(Int(memoryUsage))%, above threshold of \(Int(rule.threshold))%"
                }

            case .memoryPressure:
                if memoryHistory.count >= 30 {
                    let avg = memoryHistory.suffix(30).reduce(0, +) / 30
                    if avg >= rule.threshold {
                        shouldAlert = true
                        value = avg
                        message = "Memory has been above \(Int(rule.threshold))% for the last 30 seconds"
                    }
                }

            case .networkDisconnected:
                if !isNetworkConnected {
                    shouldAlert = true
                    value = 0
                    message = "Network connection lost"
                }

            case .networkHighUpload:
                if uploadSpeed >= rule.threshold {
                    shouldAlert = true
                    value = uploadSpeed
                    message = "Upload speed is \(ByteFormatter.formatSpeed(uploadSpeed))"
                }

            case .networkHighDownload:
                if downloadSpeed >= rule.threshold {
                    shouldAlert = true
                    value = downloadSpeed
                    message = "Download speed is \(ByteFormatter.formatSpeed(downloadSpeed))"
                }

            case .diskSpaceLow:
                if diskFreePercent <= rule.threshold {
                    shouldAlert = true
                    value = diskFreePercent
                    message = "Disk space is low: \(Int(diskFreePercent))% free"
                }

            case .processHighCPU:
                if let processName = rule.processName,
                   let process = topProcesses.first(where: {
                       $0.name.lowercased().contains(processName.lowercased())
                   }),
                   process.cpuUsage >= rule.threshold {
                    shouldAlert = true
                    value = process.cpuUsage
                    message = "\(process.name) is using \(Int(process.cpuUsage))% CPU"
                }

            case .processHighMemory:
                if let processName = rule.processName,
                   let process = topProcesses.first(where: {
                       $0.name.lowercased().contains(processName.lowercased())
                   }),
                   process.memoryUsage >= rule.threshold {
                    shouldAlert = true
                    value = process.memoryUsage
                    message = "\(process.name) is using \(PercentFormatter.format(process.memoryUsage, decimals: 1)) of memory"
                }
            }

            if shouldAlert {
                triggerAlert(rule: rule, value: value, message: message)
            }
        }
    }

    /// Check for anomalies using simple statistical detection
    func checkForAnomalies(cpuUsage: Double, memoryUsage: Double) -> (cpuAnomaly: Bool, memoryAnomaly: Bool) {
        guard cpuHistory.count >= 30, memoryHistory.count >= 30 else {
            return (false, false)
        }

        let cpuMean = cpuHistory.reduce(0, +) / Double(cpuHistory.count)
        let cpuStdDev = sqrt(cpuHistory.map { pow($0 - cpuMean, 2) }.reduce(0, +) / Double(cpuHistory.count))

        let memMean = memoryHistory.reduce(0, +) / Double(memoryHistory.count)
        let memStdDev = sqrt(memoryHistory.map { pow($0 - memMean, 2) }.reduce(0, +) / Double(memoryHistory.count))

        // Anomaly if more than 2 standard deviations from mean
        let cpuAnomaly = cpuStdDev > 0 && abs(cpuUsage - cpuMean) > 2 * cpuStdDev
        let memAnomaly = memStdDev > 0 && abs(memoryUsage - memMean) > 2 * memStdDev

        return (cpuAnomaly, memAnomaly)
    }

    /// Mark an event as read
    func markAsRead(_ event: AlertEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index].isRead = true
            updateUnreadCount()
            saveEvents()
        }
    }

    /// Mark all events as read
    func markAllAsRead() {
        for i in events.indices {
            events[i].isRead = true
        }
        updateUnreadCount()
        saveEvents()
    }

    /// Clear all events
    func clearEvents() {
        events = []
        unreadCount = 0
        saveEvents()
    }

    /// Get events for the current session
    var sessionAlertCount: Int {
        // Events from last 24 hours
        let cutoff = Date().addingTimeInterval(-86400)
        return events.filter { $0.timestamp > cutoff }.count
    }

    // MARK: - Private Methods

    private func setupDefaultRules() {
        guard rules.isEmpty else { return }

        // Add default rules
        rules = [
            AlertRule(type: .cpuHigh, threshold: 90, isEnabled: false),
            AlertRule(type: .memoryHigh, threshold: 90, isEnabled: false),
            AlertRule(type: .networkDisconnected, isEnabled: false),
            AlertRule(type: .diskSpaceLow, threshold: 10, isEnabled: false)
        ]
        saveRules()
    }

    private func updateHistory(cpu: Double, memory: Double) {
        cpuHistory.append(cpu)
        memoryHistory.append(memory)

        if cpuHistory.count > historySize {
            cpuHistory.removeFirst()
        }
        if memoryHistory.count > historySize {
            memoryHistory.removeFirst()
        }
    }

    private func triggerAlert(rule: AlertRule, value: Double, message: String) {
        // Record the alert time
        lastAlertTimes[rule.id] = Date()

        // Create event
        let event = AlertEvent(rule: rule, value: value, message: message)
        events.insert(event, at: 0)

        // Limit events to last 1000
        if events.count > 1000 {
            events = Array(events.prefix(1000))
        }

        updateUnreadCount()
        saveEvents()

        // Send macOS notification
        sendNotification(title: rule.type.rawValue, body: message)
    }

    private func sendNotification(title: String, body: String) {
        guard notificationsAvailable, let center = _notificationCenter else {
            print("Alert: \(title) - \(body)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Operator: \(title)"
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    private func updateUnreadCount() {
        unreadCount = events.filter { !$0.isRead }.count
    }

    // MARK: - Persistence

    private var rulesURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let operatorDir = appSupport.appendingPathComponent("Operator", isDirectory: true)
        try? fileManager.createDirectory(at: operatorDir, withIntermediateDirectories: true)
        return operatorDir.appendingPathComponent("alert_rules.json")
    }

    private var eventsURL: URL {
        rulesURL.deletingLastPathComponent().appendingPathComponent("alert_events.json")
    }

    private func loadRules() {
        if let data = try? Data(contentsOf: rulesURL),
           let loaded = try? decoder.decode([AlertRule].self, from: data) {
            rules = loaded
        }
    }

    private func saveRules() {
        if let data = try? encoder.encode(rules) {
            try? data.write(to: rulesURL)
        }
    }

    private func loadEvents() {
        if let data = try? Data(contentsOf: eventsURL),
           let loaded = try? decoder.decode([AlertEvent].self, from: data) {
            // Only keep events from last 7 days
            let cutoff = Date().addingTimeInterval(-7 * 86400)
            events = loaded.filter { $0.timestamp > cutoff }
            updateUnreadCount()
        }
    }

    private func saveEvents() {
        if let data = try? encoder.encode(events) {
            try? data.write(to: eventsURL)
        }
    }
}
