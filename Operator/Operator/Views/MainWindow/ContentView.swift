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
            // Deep, glassy base
            Color(.sRGB, red: 0.04, green: 0.05, blue: 0.08)
                .ignoresSafeArea()

            // Liquid Glass background
            VisualEffectBackground()

            // Subtle aurora-inspired gradient glow
            AuroraBackground()

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
    @Namespace private var selectionAnimation

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
        HStack(spacing: 6) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                TabButton(
                    icon: tab.icon,
                    label: tab.label,
                    isSelected: selectedTab == index,
                    namespace: selectionAnimation
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        selectedTab = index
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(.sRGB, red: 0.06, green: 0.08, blue: 0.12).opacity(0.55),
                                    Color(.sRGB, red: 0.03, green: 0.04, blue: 0.08).opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 10)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.26),
                                    Color.purple.opacity(0.22),
                                    Color(.sRGB, red: 0.15, green: 0.2, blue: 0.3).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                        )
                        .shadow(color: Color.accentColor.opacity(0.26), radius: 12, x: 0, y: 7)
                        .matchedGeometryEffect(id: "tabSelection", in: namespace)
                }

                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                    Text(label)
                        .font(.system(size: 11.5, weight: .medium))
                }
                .frame(maxWidth: .infinity, minHeight: 32)
                .padding(.horizontal, 8)
                .foregroundColor(isSelected ? .white : Color.white.opacity(0.68))
            }
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

// MARK: - Aurora Background

struct AuroraBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(.sRGB, red: 0.06, green: 0.08, blue: 0.12),
                        Color(.sRGB, red: 0.02, green: 0.02, blue: 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 60)

                Circle()
                    .fill(Color.cyan.opacity(0.18))
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: -geometry.size.width * 0.25, y: -geometry.size.height * 0.35)
                    .blur(radius: 110)

                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: geometry.size.width * 0.45)
                    .offset(x: geometry.size.width * 0.35, y: -geometry.size.height * 0.05)
                    .blur(radius: 110)

                RoundedRectangle(cornerRadius: 80)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.sRGB, red: 0.05, green: 0.4, blue: 0.55).opacity(0.18),
                                Color.indigo.opacity(0.14)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.6)
                    .offset(y: geometry.size.height * 0.35)
                    .blur(radius: 90)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .blendMode(.screen)
                    )
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .compositingGroup()
        .opacity(0.9)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(SystemMonitor())
}
