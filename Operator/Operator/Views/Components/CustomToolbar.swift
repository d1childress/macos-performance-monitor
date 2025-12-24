//
//  CustomToolbar.swift
//  Operator
//
//  Customizable native macOS toolbar with liquid glass styling.
//

import SwiftUI
import AppKit

struct CustomToolbar: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @AppStorage("toolbarItems") private var toolbarItemsData: Data = Data()
    @State private var availableItems: [ToolbarItem] = ToolbarItem.defaultItems
    @State private var activeItems: [ToolbarItem] = ToolbarItem.defaultItems
    @State private var showCustomization = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(activeItems) { item in
                ToolbarButton(item: item, systemMonitor: systemMonitor)
            }

            Spacer()

            Button {
                showCustomization.toggle()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .allowsHitTesting(true)
            .popover(isPresented: $showCustomization) {
                ToolbarCustomizationView(
                    availableItems: $availableItems,
                    activeItems: $activeItems
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .onAppear {
            loadToolbarItems()
        }
        .onChange(of: activeItems) { _ in
            saveToolbarItems()
        }
    }

    private func loadToolbarItems() {
        if let decoded = try? JSONDecoder().decode([ToolbarItem].self, from: toolbarItemsData) {
            activeItems = decoded
        }
    }

    private func saveToolbarItems() {
        if let encoded = try? JSONEncoder().encode(activeItems) {
            toolbarItemsData = encoded
        }
    }
}

// MARK: - Toolbar Item

struct ToolbarItem: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let icon: String
    let action: ToolbarAction

    static let defaultItems: [ToolbarItem] = [
        ToolbarItem(id: UUID(), title: "Refresh", icon: "arrow.clockwise", action: .refresh),
        ToolbarItem(id: UUID(), title: "Network Diagnostics", icon: "stethoscope", action: .networkDiagnostics),
        ToolbarItem(id: UUID(), title: "Settings", icon: "gearshape", action: .settings)
    ]

    static let availableItems: [ToolbarItem] = [
        ToolbarItem(id: UUID(), title: "Refresh", icon: "arrow.clockwise", action: .refresh),
        ToolbarItem(id: UUID(), title: "Network Diagnostics", icon: "stethoscope", action: .networkDiagnostics),
        ToolbarItem(id: UUID(), title: "Settings", icon: "gearshape", action: .settings),
        ToolbarItem(id: UUID(), title: "Processes", icon: "list.bullet.rectangle", action: .processes),
        ToolbarItem(id: UUID(), title: "History", icon: "clock.arrow.circlepath", action: .history),
        ToolbarItem(id: UUID(), title: "Export", icon: "square.and.arrow.up", action: .export)
    ]
}

enum ToolbarAction: String, Codable {
    case refresh
    case networkDiagnostics
    case settings
    case processes
    case history
    case export
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let item: ToolbarItem
    let systemMonitor: SystemMonitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            performAction()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(item.title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.1))
            )
            .foregroundColor(.accentColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .allowsHitTesting(true)
        .help(item.title)
    }

    private func performAction() {
        switch item.action {
        case .refresh:
            systemMonitor.forceRefresh()
        case .networkDiagnostics:
            NotificationCenter.default.post(name: .switchTab, object: 3)
            // Could also open a separate window for diagnostics
        case .settings:
            if #available(macOS 13, *) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } else {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        case .processes:
            NotificationCenter.default.post(name: .switchTab, object: 4)
        case .history:
            NotificationCenter.default.post(name: .switchTab, object: 6)
        case .export:
            // Export functionality
            break
        }
    }
}

// MARK: - Toolbar Customization View

struct ToolbarCustomizationView: View {
    @Binding var availableItems: [ToolbarItem]
    @Binding var activeItems: [ToolbarItem]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Customize Toolbar")
                .font(.headline)
                .padding(.bottom, 4)

            Text("Drag items to reorder, or remove items you don't need")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Active Items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(activeItems) { item in
                    HStack {
                        Image(systemName: item.icon)
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                        Text(item.title)
                            .font(.caption)

                        Spacer()

                        Button {
                            activeItems.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                        .allowsHitTesting(true)
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Available Items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(availableItems.filter { !activeItems.contains($0) }) { item in
                    HStack {
                        Image(systemName: item.icon)
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                        Text(item.title)
                            .font(.caption)

                        Spacer()

                        Button {
                            activeItems.append(item)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.borderless)
                        .allowsHitTesting(true)
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer()

            HStack {
                Button("Reset to Defaults") {
                    activeItems = ToolbarItem.defaultItems
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300, height: 400)
    }
}

