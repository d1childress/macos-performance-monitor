//
//  ContentView.swift
//  Operator
//
//  Main tabbed interface for the application.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            // Liquid Glass background
            VisualEffectBackground()

            VStack(spacing: 0) {
                // Custom tab bar
                TabBarView(selectedTab: $selectedTab)

                // Tab content
                TabView(selection: $selectedTab) {
                    OverviewView()
                        .tag(0)

                    CPUView()
                        .tag(1)

                    MemoryView()
                        .tag(2)

                    NetworkView()
                        .tag(3)

                    NetworkDiagnosticsView()
                        .tag(4)

                    ProcessesView()
                        .tag(5)

                    BatteryView()
                        .tag(6)

                    HistoryView()
                        .tag(7)
                }
                .tabViewStyle(.automatic)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: .switchTab)) { notification in
            if let tab = notification.object as? Int {
                withAnimation {
                    selectedTab = tab
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceRefresh"))) { _ in
            systemMonitor.forceRefresh()
        }
    }
}

// MARK: - Tab Bar

struct TabBarView: View {
    @Binding var selectedTab: Int

    private let tabs: [(icon: String, label: String)] = [
        ("square.grid.2x2", "Overview"),
        ("cpu", "CPU"),
        ("memorychip", "Memory"),
        ("network", "Network"),
        ("stethoscope", "Diagnostics"),
        ("list.bullet.rectangle", "Processes"),
        ("battery.100", "Battery"),
        ("clock.arrow.circlepath", "History")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                TabButton(
                    icon: tab.icon,
                    label: tab.label,
                    isSelected: selectedTab == index
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .allowsHitTesting(true)
    }
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(SystemMonitor())
}
