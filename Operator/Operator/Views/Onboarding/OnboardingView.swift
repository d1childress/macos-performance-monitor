//
//  OnboardingView.swift
//  Operator
//
//  Guided onboarding flow for first-time users.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "gauge.with.dots.needle.bottom.50percent",
            title: "Welcome to Operator",
            subtitle: "Your Mac's Performance at a Glance",
            description: "Monitor CPU, memory, network, disk, and battery in real-time with a beautiful, native macOS interface.",
            features: [
                ("cpu", "CPU & Memory Monitoring"),
                ("network", "Network Speed Tracking"),
                ("battery.100", "Battery & Thermal Stats"),
                ("list.bullet.rectangle", "Process Management")
            ]
        ),
        OnboardingPage(
            icon: "menubar.rectangle",
            title: "Menu Bar Integration",
            subtitle: "Always Accessible",
            description: "Keep an eye on your system from the menu bar. Click to see a quick overview or open the full dashboard.",
            features: [
                ("arrow.up.arrow.down", "Live Network Speeds"),
                ("cpu", "CPU Usage Display"),
                ("gearshape", "Customizable Display")
            ]
        ),
        OnboardingPage(
            icon: "bell.badge",
            title: "Smart Alerts",
            subtitle: "Stay Informed",
            description: "Set up custom alerts to notify you when system resources reach critical levels.",
            features: [
                ("exclamationmark.triangle", "Configurable Thresholds"),
                ("bell", "macOS Notifications"),
                ("chart.line.uptrend.xyaxis", "Anomaly Detection")
            ]
        ),
        OnboardingPage(
            icon: "person.2",
            title: "Usage Profiles",
            subtitle: "Optimize for Your Workflow",
            description: "Choose from preset profiles or create your own to match your usage patterns.",
            features: [
                ("battery.75", "Battery Saver"),
                ("hammer", "Developer Mode"),
                ("play.tv", "Streaming Mode"),
                ("gamecontroller", "Gaming Mode")
            ]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)

            // Bottom controls
            HStack {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .onTapGesture {
                                withAnimation {
                                    currentPage = index
                                }
                            }
                    }
                }

                Spacer()

                // Navigation buttons
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .frame(width: 600, height: 500)
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        isPresented = false
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let features: [(icon: String, text: String)]
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Title
            VStack(spacing: 8) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(page.subtitle)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)

            // Features
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(page.features.enumerated()), id: \.offset) { _, feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .frame(width: 30)

                        Text(feature.text)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(Color.primary.opacity(0.03))
            .cornerRadius(12)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Onboarding Modifier

struct OnboardingModifier: ViewModifier {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !hasCompletedOnboarding {
                    showOnboarding = true
                }
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
    }
}

extension View {
    func withOnboarding() -> some View {
        modifier(OnboardingModifier())
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(isPresented: .constant(true))
}
