//
//  NetworkDiagnostics.swift
//  Operator
//
//  Network diagnostic tools: ping, nslookup, whois.
//

import Foundation

/// Network diagnostic tool types
enum NetworkDiagnosticTool: String, CaseIterable {
    case ping = "Ping"
    case nslookup = "NSLookup"
    case whois = "Whois"

    var icon: String {
        switch self {
        case .ping: return "network"
        case .nslookup: return "magnifyingglass"
        case .whois: return "info.circle"
        }
    }

    var command: String {
        switch self {
        case .ping: return "/sbin/ping"
        case .nslookup: return "/usr/bin/nslookup"
        case .whois: return "/usr/bin/whois"
        }
    }
}

/// Result of a network diagnostic operation
struct NetworkDiagnosticResult {
    let success: Bool
    let output: String
    let error: String?

    static func success(_ output: String) -> NetworkDiagnosticResult {
        NetworkDiagnosticResult(success: true, output: output, error: nil)
    }

    static func failure(_ error: String, output: String = "") -> NetworkDiagnosticResult {
        NetworkDiagnosticResult(success: false, output: output, error: error)
    }
}

/// Handles network diagnostic operations
class NetworkDiagnostics {
    static let shared = NetworkDiagnostics()

    private init() {}

    /// Run a ping command
    func ping(host: String, count: Int = 4, interval: Double = 1.0) async -> NetworkDiagnosticResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/ping")
        var arguments = ["-c", String(count)]
        
        // Add interval if specified (macOS ping uses -i for interval)
        if interval != 1.0 {
            arguments.append("-i")
            arguments.append(String(Int(interval)))
        }
        
        arguments.append(host)
        task.arguments = arguments

        return await runCommand(task: task, tool: .ping, host: host)
    }

    /// Run an nslookup command
    func nslookup(host: String) async -> NetworkDiagnosticResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nslookup")
        task.arguments = [host]

        return await runCommand(task: task, tool: .nslookup, host: host)
    }

    /// Run a whois command
    func whois(domain: String) async -> NetworkDiagnosticResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/whois")
        task.arguments = [domain]

        return await runCommand(task: task, tool: .whois, host: domain)
    }

    // MARK: - Private Methods

    private func runCommand(task: Process, tool: NetworkDiagnosticTool, host: String) async -> NetworkDiagnosticResult {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()

            return await withCheckedContinuation { continuation in
                task.terminationHandler = { process in
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: .success(output.isEmpty ? "Command completed successfully" : output))
                    } else {
                        let errorMessage = error.isEmpty ? "Command failed with exit code \(process.terminationStatus)" : error
                        continuation.resume(returning: .failure(errorMessage, output: output))
                    }
                }
            }
        } catch {
            return .failure("Failed to start \(tool.rawValue): \(error.localizedDescription)")
        }
    }
}

