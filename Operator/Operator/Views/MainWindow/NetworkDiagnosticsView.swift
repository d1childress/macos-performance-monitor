//
//  NetworkDiagnosticsView.swift
//  Operator
//
//  Network diagnostics tools: ping, nslookup, whois.
//

import SwiftUI
import AppKit

struct NetworkDiagnosticsView: View {
    @State private var diagnosticHost = ""
    @State private var selectedTool: NetworkDiagnosticTool = .ping
    @State private var diagnosticResult: NetworkDiagnosticResult?
    @State private var isRunningDiagnostic = false
    @State private var pingCount: Int = 4
    @State private var showPingOptions = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Network Diagnostics
                GlassPanel(title: "Network Diagnostics", icon: "stethoscope") {
                    VStack(spacing: 16) {
                        // Tool selection with enhanced styling
                        HStack(spacing: 8) {
                            ForEach(NetworkDiagnosticTool.allCases, id: \.self) { tool in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedTool = tool
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: tool.icon)
                                            .font(.system(size: 12, weight: .medium))
                                        Text(tool.rawValue)
                                            .font(.system(size: 13))
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Group {
                                            if selectedTool == tool {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.accentColor.opacity(0.25),
                                                                Color.accentColor.opacity(0.15)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                                    )
                                            } else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.primary.opacity(0.05))
                                            }
                                        }
                                    )
                                    .foregroundColor(selectedTool == tool ? .accentColor : .secondary)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                                .allowsHitTesting(true)
                            }
                        }

                        // Enhanced input field
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: selectedTool == .ping ? "network" :
                                          selectedTool == .nslookup ? "magnifyingglass" : "info.circle")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 12))

                                    TextField(
                                        selectedTool == .ping ? "Host or IP address" :
                                        selectedTool == .nslookup ? "Hostname or IP address" :
                                        "Domain name",
                                        text: $diagnosticHost
                                    )
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                        )
                                )
                                .onSubmit {
                                    runDiagnostic()
                                }

                                if selectedTool == .ping {
                                    Button {
                                        withAnimation {
                                            showPingOptions.toggle()
                                        }
                                    } label: {
                                        Image(systemName: "slider.horizontal.3")
                                            .foregroundColor(.accentColor)
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(.borderless)
                                    .allowsHitTesting(true)
                                    .help("Ping Options")
                                }

                                Button {
                                    runDiagnostic()
                                } label: {
                                    HStack(spacing: 6) {
                                        if isRunningDiagnostic {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .progressViewStyle(.circular)
                                        } else {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        Text("Run")
                                            .font(.system(size: 13))
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.accentColor.opacity(0.3),
                                                        Color.accentColor.opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(.accentColor)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                                .allowsHitTesting(true)
                                .disabled(isRunningDiagnostic || diagnosticHost.isEmpty)
                            }

                            // Ping options
                            if selectedTool == .ping && showPingOptions {
                                HStack(spacing: 12) {
                                    Text("Count:")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)

                                    Stepper(value: $pingCount, in: 1...20) {
                                        Text("\(pingCount)")
                                            .font(.system(size: 13))
                                            .monospacedDigit()
                                            .frame(width: 30)
                                    }
                                    .labelsHidden()

                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.primary.opacity(0.03))
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }

                        // Enhanced results display
                        if let result = diagnosticResult {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    HStack(spacing: 6) {
                                        StatusIndicator(result.success ? .green : .red, size: 10)
                                        Text(result.success ? "Success" : "Error")
                                            .font(.system(size: 13))
                                            .fontWeight(.semibold)
                                            .foregroundColor(result.success ? .green : .red)
                                    }

                                    Spacer()

                                    HStack(spacing: 8) {
                                        Button {
                                            // Copy to clipboard
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(result.output, forType: .string)
                                        } label: {
                                            Image(systemName: "doc.on.clipboard")
                                                .foregroundColor(.secondary)
                                                .font(.system(size: 11))
                                        }
                                        .buttonStyle(.borderless)
                                        .allowsHitTesting(true)
                                        .help("Copy to clipboard")

                                        Button {
                                            withAnimation(.spring()) {
                                                diagnosticResult = nil
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                                .font(.system(size: 14))
                                        }
                                        .buttonStyle(.borderless)
                                        .allowsHitTesting(true)
                                    }
                                }

                                ScrollView {
                                    Text(result.output.isEmpty ? (result.error ?? "No output") : result.output)
                                        .font(.system(size: 11, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                }
                                .frame(maxHeight: 220)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    result.success ?
                                                    Color.green.opacity(0.2) :
                                                    Color.red.opacity(0.2),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            colors: result.success ?
                                            [Color.green.opacity(0.08), Color.green.opacity(0.03)] :
                                            [Color.red.opacity(0.08), Color.red.opacity(0.03)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                result.success ?
                                                Color.green.opacity(0.15) :
                                                Color.red.opacity(0.15),
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func runDiagnostic() {
        guard !diagnosticHost.isEmpty && !isRunningDiagnostic else { return }

        isRunningDiagnostic = true
        diagnosticResult = nil

        Task {
            let result: NetworkDiagnosticResult

            switch selectedTool {
            case .ping:
                result = await NetworkDiagnostics.shared.ping(host: diagnosticHost, count: pingCount)
            case .nslookup:
                result = await NetworkDiagnostics.shared.nslookup(host: diagnosticHost)
            case .whois:
                result = await NetworkDiagnostics.shared.whois(domain: diagnosticHost)
            }

            await MainActor.run {
                self.diagnosticResult = result
                self.isRunningDiagnostic = false
            }
        }
    }
}

