//
//  NetworkMonitor.swift
//  Operator
//
//  Network monitoring using getifaddrs and NWPathMonitor.
//

import Foundation
import Network
import Darwin

class NetworkMonitor {
    // Previous values for rate calculation
    private var previousBytes: [String: (sent: UInt64, received: UInt64)] = [:]
    private var previousTimestamp: Date?

    // NWPathMonitor for connection status
    private var pathMonitor: NWPathMonitor?
    private var isConnected = true
    private var connectionType = "Unknown"

    func getMetrics() -> NetworkMetrics {
        let currentStats = NetworkHelpers.getInterfaceStats()
        let currentTime = Date()

        var totalBytesSent: UInt64 = 0
        var totalBytesReceived: UInt64 = 0
        var totalUploadSpeed: Double = 0
        var totalDownloadSpeed: Double = 0
        var interfaces: [NetworkInterfaceInfo] = []

        let timeDelta = previousTimestamp.map { currentTime.timeIntervalSince($0) } ?? 1.0

        for (name, stats) in currentStats {
            // Skip loopback and system interfaces for total calculation
            let isPhysical = name.hasPrefix("en") || name.hasPrefix("bridge")

            if isPhysical {
                totalBytesSent += stats.bytesSent
                totalBytesReceived += stats.bytesReceived
            }

            // Calculate speeds
            var uploadSpeed: Double = 0
            var downloadSpeed: Double = 0

            if let prev = previousBytes[name], timeDelta > 0 {
                let sentDelta = stats.bytesSent > prev.sent ? stats.bytesSent - prev.sent : 0
                let recvDelta = stats.bytesReceived > prev.received ? stats.bytesReceived - prev.received : 0

                uploadSpeed = Double(sentDelta) / timeDelta
                downloadSpeed = Double(recvDelta) / timeDelta

                if isPhysical {
                    totalUploadSpeed += uploadSpeed
                    totalDownloadSpeed += downloadSpeed
                }
            }

            // Store current values for next calculation
            previousBytes[name] = (stats.bytesSent, stats.bytesReceived)

            // Only include physical and VPN interfaces in the list
            if isPhysical || name.hasPrefix("utun") || name.hasPrefix("ipsec") {
                let displayName = getDisplayName(for: name)
                interfaces.append(NetworkInterfaceInfo(
                    name: name,
                    displayName: displayName,
                    ipAddress: stats.ipAddress,
                    macAddress: nil,
                    bytesSent: stats.bytesSent,
                    bytesReceived: stats.bytesReceived,
                    uploadSpeed: uploadSpeed,
                    downloadSpeed: downloadSpeed,
                    isUp: stats.isUp
                ))
            }
        }

        previousTimestamp = currentTime

        // Sort interfaces: en0 first, then by name
        interfaces.sort { lhs, rhs in
            if lhs.name == "en0" { return true }
            if rhs.name == "en0" { return false }
            return lhs.name < rhs.name
        }

        return NetworkMetrics(
            bytesSent: totalBytesSent,
            bytesReceived: totalBytesReceived,
            uploadSpeed: totalUploadSpeed,
            downloadSpeed: totalDownloadSpeed,
            interfaces: interfaces,
            isConnected: isConnected,
            connectionType: connectionType
        )
    }

    // MARK: - Path Monitor

    func startPathMonitor() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(from: path) ?? "Unknown"
            }
        }
        pathMonitor?.start(queue: DispatchQueue.global(qos: .utility))
    }

    func stopPathMonitor() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    // MARK: - Private Methods

    private func getDisplayName(for interface: String) -> String {
        switch interface {
        case "en0":
            return "Wi-Fi"
        case "en1", "en2", "en3", "en4", "en5":
            return "Ethernet"
        case "lo0":
            return "Loopback"
        case "bridge0", "bridge100":
            return "Bridge"
        case let name where name.hasPrefix("utun"):
            return "VPN Tunnel"
        case let name where name.hasPrefix("ipsec"):
            return "IPSec VPN"
        case let name where name.hasPrefix("awdl"):
            return "AWDL"
        case let name where name.hasPrefix("llw"):
            return "Low Latency WLAN"
        default:
            return interface
        }
    }

    private func getConnectionType(from path: NWPath) -> String {
        if path.usesInterfaceType(.wifi) {
            return "Wi-Fi"
        } else if path.usesInterfaceType(.wiredEthernet) {
            return "Ethernet"
        } else if path.usesInterfaceType(.cellular) {
            return "Cellular"
        } else if path.usesInterfaceType(.loopback) {
            return "Loopback"
        } else {
            return "Other"
        }
    }
}
