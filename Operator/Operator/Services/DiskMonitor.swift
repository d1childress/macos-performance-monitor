//
//  DiskMonitor.swift
//  Operator
//
//  Disk monitoring using FileManager and IOKit.
//

import Foundation
import IOKit
import IOKit.storage

class DiskMonitor {
    private var previousIOStats: (read: UInt64, write: UInt64)?
    private var previousTimestamp: Date?

    func getMetrics() -> DiskMetrics {
        let volumes = getVolumes()
        let ioStats = getDiskIOStats()

        let currentTime = Date()
        var readSpeed: Double = 0
        var writeSpeed: Double = 0

        if let prev = previousIOStats,
           let prevTime = previousTimestamp {
            let timeDelta = currentTime.timeIntervalSince(prevTime)
            if timeDelta > 0 {
                let readDelta = ioStats.read > prev.read ? ioStats.read - prev.read : 0
                let writeDelta = ioStats.write > prev.write ? ioStats.write - prev.write : 0

                readSpeed = Double(readDelta) / timeDelta
                writeSpeed = Double(writeDelta) / timeDelta
            }
        }

        previousIOStats = (ioStats.read, ioStats.write)
        previousTimestamp = currentTime

        return DiskMetrics(
            volumes: volumes,
            readBytesPerSec: readSpeed,
            writeBytesPerSec: writeSpeed,
            totalReadBytes: ioStats.read,
            totalWriteBytes: ioStats.write
        )
    }

    // MARK: - Private Methods

    private func getVolumes() -> [VolumeInfo] {
        let fileManager = FileManager.default
        var volumes: [VolumeInfo] = []

        // Get mounted volumes
        guard let urls = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey],
            options: [.skipHiddenVolumes]
        ) else {
            return volumes
        }

        for url in urls {
            do {
                let resourceValues = try url.resourceValues(forKeys: [
                    .volumeNameKey,
                    .volumeTotalCapacityKey,
                    .volumeAvailableCapacityKey,
                    .volumeIsLocalKey,
                    .volumeIsReadOnlyKey
                ])

                // Skip non-local volumes
                guard resourceValues.volumeIsLocal == true else { continue }

                let name = resourceValues.volumeName ?? url.lastPathComponent
                let total = UInt64(resourceValues.volumeTotalCapacity ?? 0)
                let available = UInt64(resourceValues.volumeAvailableCapacity ?? 0)
                let used = total > available ? total - available : 0

                volumes.append(VolumeInfo(
                    name: name,
                    mountPoint: url.path,
                    totalBytes: total,
                    usedBytes: used,
                    freeBytes: available,
                    fileSystem: getFileSystem(for: url)
                ))
            } catch {
                continue
            }
        }

        // Sort: root volume first, then alphabetically
        volumes.sort { lhs, rhs in
            if lhs.mountPoint == "/" { return true }
            if rhs.mountPoint == "/" { return false }
            return lhs.name < rhs.name
        }

        return volumes
    }

    private func getFileSystem(for url: URL) -> String {
        do {
            let values = try url.resourceValues(forKeys: [.volumeLocalizedFormatDescriptionKey])
            return values.volumeLocalizedFormatDescription ?? "Unknown"
        } catch {
            return "Unknown"
        }
    }

    private func getDiskIOStats() -> (read: UInt64, write: UInt64) {
        // Use IOKit to get disk I/O statistics
        var iterator: io_iterator_t = 0

        let matchingDict = IOServiceMatching(kIOMediaClass)
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return (0, 0)
        }

        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        var disk = IOIteratorNext(iterator)
        while disk != 0 {
            var parent: io_object_t = 0

            // Get parent (driver) to access statistics
            if IORegistryEntryGetParentEntry(disk, kIOServicePlane, &parent) == KERN_SUCCESS {
                if let stats = IORegistryEntryCreateCFProperty(
                    parent,
                    "Statistics" as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue() as? [String: Any] {

                    if let read = stats["Bytes (Read)"] as? UInt64 {
                        totalRead += read
                    }
                    if let write = stats["Bytes (Write)"] as? UInt64 {
                        totalWrite += write
                    }
                }
                IOObjectRelease(parent)
            }

            IOObjectRelease(disk)
            disk = IOIteratorNext(iterator)
        }

        return (totalRead, totalWrite)
    }
}
