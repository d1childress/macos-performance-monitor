//
//  AppDelegate.swift
//  Operator
//
//  Handles app lifecycle and additional macOS integration.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure app to run as accessory (menu bar only option)
        // Uncomment the line below to hide dock icon:
        // NSApp.setActivationPolicy(.accessory)

        // Set up any necessary permissions or initial state
        setupAppearance()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up resources
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in menu bar when window is closed
        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Private Methods

    private func setupAppearance() {
        // Enable Liquid Glass visual effect view for all windows
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                self.configureWindow(window)
            }
        }
        
        // Monitor for new windows
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let window = notification.object as? NSWindow {
                self?.configureWindow(window)
            }
        }
    }
    
    private func configureWindow(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.titleVisibility = .hidden
        
        // Enhanced window styling
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.masksToBounds = false
        }
        
        // Set up native toolbar if not already set
        if window.toolbar == nil && window.identifier?.rawValue == "main" {
            let toolbar = NSToolbar(identifier: "MainToolbar")
            toolbar.delegate = ToolbarDelegate.shared
            toolbar.displayMode = .iconOnly
            toolbar.allowsUserCustomization = true
            window.toolbar = toolbar
        }
    }
}

// MARK: - Toolbar Delegate

class ToolbarDelegate: NSObject, NSToolbarDelegate {
    static let shared = ToolbarDelegate()
    
    private override init() {
        super.init()
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .refresh,
            .networkDiagnostics,
            .flexibleSpace,
            .settings
        ]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .refresh,
            .networkDiagnostics,
            .processes,
            .history,
            .export,
            .flexibleSpace,
            .settings
        ]
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        
        switch itemIdentifier {
        case .refresh:
            item.label = "Refresh"
            item.paletteLabel = "Refresh"
            item.toolTip = "Refresh Now"
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
            item.action = #selector(refreshAction)
            item.target = self
            
        case .networkDiagnostics:
            item.label = "Network Diagnostics"
            item.paletteLabel = "Network Diagnostics"
            item.toolTip = "Network Diagnostics"
            item.image = NSImage(systemSymbolName: "stethoscope", accessibilityDescription: "Network Diagnostics")
            item.action = #selector(networkDiagnosticsAction)
            item.target = self
            
        case .processes:
            item.label = "Processes"
            item.paletteLabel = "Processes"
            item.toolTip = "View Processes"
            item.image = NSImage(systemSymbolName: "list.bullet.rectangle", accessibilityDescription: "Processes")
            item.action = #selector(processesAction)
            item.target = self
            
        case .history:
            item.label = "History"
            item.paletteLabel = "History"
            item.toolTip = "View History"
            item.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "History")
            item.action = #selector(historyAction)
            item.target = self
            
        case .export:
            item.label = "Export"
            item.paletteLabel = "Export"
            item.toolTip = "Export Data"
            item.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Export")
            item.action = #selector(exportAction)
            item.target = self
            
        case .settings:
            item.label = "Settings"
            item.paletteLabel = "Settings"
            item.toolTip = "Settings"
            item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
            item.action = #selector(settingsAction)
            item.target = self
            
        default:
            return nil
        }
        
        return item
    }
    
    @objc func refreshAction() {
        NotificationCenter.default.post(name: NSNotification.Name("ForceRefresh"), object: nil)
    }
    
    @objc func networkDiagnosticsAction() {
        NotificationCenter.default.post(name: .switchTab, object: 4)
    }
    
    @objc func processesAction() {
        NotificationCenter.default.post(name: .switchTab, object: 5)
    }
    
    @objc func historyAction() {
        NotificationCenter.default.post(name: .switchTab, object: 7)
    }
    
    @objc func exportAction() {
        // Export functionality
    }
    
    @objc func settingsAction() {
        if #available(macOS 13, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

extension NSToolbarItem.Identifier {
    static let refresh = NSToolbarItem.Identifier("com.operator.refresh")
    static let networkDiagnostics = NSToolbarItem.Identifier("com.operator.networkDiagnostics")
    static let processes = NSToolbarItem.Identifier("com.operator.processes")
    static let history = NSToolbarItem.Identifier("com.operator.history")
    static let export = NSToolbarItem.Identifier("com.operator.export")
    static let settings = NSToolbarItem.Identifier("com.operator.settings")
}
