//
//  ProfileManager.swift
//  Operator
//
//  Manages usage profiles for different scenarios (Battery Saver, Developer, Streaming, Gaming).
//

import Foundation
import Combine

/// Available usage profiles
enum UsageProfile: String, Codable, CaseIterable, Identifiable {
    case standard = "Standard"
    case batterySaver = "Battery Saver"
    case developer = "Developer"
    case streaming = "Streaming"
    case gaming = "Gaming"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .standard: return "gearshape"
        case .batterySaver: return "battery.75"
        case .developer: return "hammer"
        case .streaming: return "play.tv"
        case .gaming: return "gamecontroller"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return "Balanced monitoring for everyday use"
        case .batterySaver:
            return "Reduced refresh rate and minimal features to conserve battery"
        case .developer:
            return "Focus on CPU, memory, and process monitoring"
        case .streaming:
            return "Prioritizes network monitoring and stability"
        case .gaming:
            return "Focus on GPU, CPU temps, and frame-related metrics"
        }
    }
}

/// Profile configuration settings
struct ProfileSettings: Codable, Equatable {
    var refreshInterval: TimeInterval
    var historyLength: Int
    var showMenuBar: Bool
    var menuBarDisplay: String
    var enabledAlerts: [AlertType]
    var priorityMetrics: [String]
    var processCount: Int

    static let standard = ProfileSettings(
        refreshInterval: 1.0,
        historyLength: 60,
        showMenuBar: true,
        menuBarDisplay: "networkSpeeds",
        enabledAlerts: [.cpuHigh, .memoryHigh, .networkDisconnected],
        priorityMetrics: ["cpu", "memory", "network", "disk"],
        processCount: 50
    )

    static let batterySaver = ProfileSettings(
        refreshInterval: 5.0,
        historyLength: 30,
        showMenuBar: true,
        menuBarDisplay: "iconOnly",
        enabledAlerts: [.memoryHigh],
        priorityMetrics: ["memory", "disk"],
        processCount: 20
    )

    static let developer = ProfileSettings(
        refreshInterval: 0.5,
        historyLength: 120,
        showMenuBar: true,
        menuBarDisplay: "cpuUsage",
        enabledAlerts: [.cpuHigh, .cpuSustained, .memoryHigh, .memoryPressure, .processHighCPU],
        priorityMetrics: ["cpu", "memory", "processes"],
        processCount: 100
    )

    static let streaming = ProfileSettings(
        refreshInterval: 1.0,
        historyLength: 60,
        showMenuBar: true,
        menuBarDisplay: "networkSpeeds",
        enabledAlerts: [.networkDisconnected, .networkHighUpload, .cpuHigh],
        priorityMetrics: ["network", "cpu"],
        processCount: 30
    )

    static let gaming = ProfileSettings(
        refreshInterval: 0.5,
        historyLength: 60,
        showMenuBar: true,
        menuBarDisplay: "cpuUsage",
        enabledAlerts: [.cpuHigh, .memoryHigh],
        priorityMetrics: ["cpu", "gpu", "memory", "thermals"],
        processCount: 30
    )

    static func settings(for profile: UsageProfile) -> ProfileSettings {
        switch profile {
        case .standard: return .standard
        case .batterySaver: return .batterySaver
        case .developer: return .developer
        case .streaming: return .streaming
        case .gaming: return .gaming
        }
    }
}

/// Custom profile created by user
struct CustomProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var settings: ProfileSettings
    var icon: String
    var createdAt: Date

    init(name: String, settings: ProfileSettings, icon: String = "star") {
        self.id = UUID()
        self.name = name
        self.settings = settings
        self.icon = icon
        self.createdAt = Date()
    }
}

/// Manages usage profiles and applies settings
@MainActor
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    // MARK: - Published Properties

    @Published var activeProfile: UsageProfile = .standard
    @Published var customProfiles: [CustomProfile] = []
    @Published var activeCustomProfile: CustomProfile?

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var currentSettings: ProfileSettings {
        if let custom = activeCustomProfile {
            return custom.settings
        }
        return ProfileSettings.settings(for: activeProfile)
    }

    // MARK: - Initialization

    private init() {
        loadProfiles()
        loadActiveProfile()
    }

    // MARK: - Public Methods

    /// Activate a built-in profile
    func activate(_ profile: UsageProfile) {
        activeProfile = profile
        activeCustomProfile = nil
        applySettings(ProfileSettings.settings(for: profile))
        saveActiveProfile()
    }

    /// Activate a custom profile
    func activateCustom(_ profile: CustomProfile) {
        activeCustomProfile = profile
        applySettings(profile.settings)
        saveActiveProfile()
    }

    /// Create a new custom profile from current settings
    func createCustomProfile(name: String, from settings: ProfileSettings, icon: String = "star") -> CustomProfile {
        let profile = CustomProfile(name: name, settings: settings, icon: icon)
        customProfiles.append(profile)
        saveProfiles()
        return profile
    }

    /// Update an existing custom profile
    func updateCustomProfile(_ profile: CustomProfile) {
        if let index = customProfiles.firstIndex(where: { $0.id == profile.id }) {
            customProfiles[index] = profile
            if activeCustomProfile?.id == profile.id {
                activeCustomProfile = profile
                applySettings(profile.settings)
            }
            saveProfiles()
        }
    }

    /// Delete a custom profile
    func deleteCustomProfile(_ profile: CustomProfile) {
        customProfiles.removeAll { $0.id == profile.id }
        if activeCustomProfile?.id == profile.id {
            activeCustomProfile = nil
            activate(.standard)
        }
        saveProfiles()
    }

    /// Get all available profiles (built-in + custom)
    var allProfiles: [(name: String, icon: String, isCustom: Bool, id: String)] {
        var profiles: [(String, String, Bool, String)] = []

        for profile in UsageProfile.allCases {
            profiles.append((profile.rawValue, profile.icon, false, profile.rawValue))
        }

        for custom in customProfiles {
            profiles.append((custom.name, custom.icon, true, custom.id.uuidString))
        }

        return profiles
    }

    /// Apply profile settings to the system
    private func applySettings(_ settings: ProfileSettings) {
        // Update UserDefaults with profile settings
        UserDefaults.standard.set(settings.refreshInterval, forKey: "refreshInterval")
        UserDefaults.standard.set(settings.historyLength, forKey: "historyLength")
        UserDefaults.standard.set(settings.showMenuBar, forKey: "showMenuBarIcon")
        UserDefaults.standard.set(settings.menuBarDisplay, forKey: "menuBarDisplay")
        UserDefaults.standard.set(settings.processCount, forKey: "processCount")

        // Notify observers
        NotificationCenter.default.post(name: .profileChanged, object: settings)
    }

    // MARK: - Persistence

    private var profilesURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let operatorDir = appSupport.appendingPathComponent("Operator", isDirectory: true)
        try? fileManager.createDirectory(at: operatorDir, withIntermediateDirectories: true)
        return operatorDir.appendingPathComponent("custom_profiles.json")
    }

    private var activeProfileURL: URL {
        profilesURL.deletingLastPathComponent().appendingPathComponent("active_profile.json")
    }

    private func loadProfiles() {
        if let data = try? Data(contentsOf: profilesURL),
           let loaded = try? decoder.decode([CustomProfile].self, from: data) {
            customProfiles = loaded
        }
    }

    private func saveProfiles() {
        if let data = try? encoder.encode(customProfiles) {
            try? data.write(to: profilesURL)
        }
    }

    private func loadActiveProfile() {
        struct ActiveProfileData: Codable {
            let builtIn: String?
            let customId: String?
        }

        if let data = try? Data(contentsOf: activeProfileURL),
           let loaded = try? decoder.decode(ActiveProfileData.self, from: data) {
            if let customId = loaded.customId,
               let uuid = UUID(uuidString: customId),
               let custom = customProfiles.first(where: { $0.id == uuid }) {
                activateCustom(custom)
            } else if let builtIn = loaded.builtIn,
                      let profile = UsageProfile(rawValue: builtIn) {
                activate(profile)
            }
        }
    }

    private func saveActiveProfile() {
        struct ActiveProfileData: Codable {
            let builtIn: String?
            let customId: String?
        }

        let data = ActiveProfileData(
            builtIn: activeCustomProfile == nil ? activeProfile.rawValue : nil,
            customId: activeCustomProfile?.id.uuidString
        )

        if let encoded = try? encoder.encode(data) {
            try? encoded.write(to: activeProfileURL)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let profileChanged = Notification.Name("profileChanged")
}
