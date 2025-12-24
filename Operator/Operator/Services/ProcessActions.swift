//
//  ProcessActions.swift
//  Operator
//
//  Actions that can be performed on processes (Reveal in Finder, Sample, Quit/Kill).
//

import Foundation
import AppKit

/// Actions that can be performed on a process
enum ProcessAction: String, CaseIterable {
    case revealInFinder = "Reveal in Finder"
    case sample = "Sample Process"
    case quit = "Quit"
    case forceQuit = "Force Quit"
    case copyPID = "Copy PID"
    case copyPath = "Copy Path"
    case openActivityMonitor = "Open in Activity Monitor"

    var icon: String {
        switch self {
        case .revealInFinder: return "folder"
        case .sample: return "waveform.path.ecg"
        case .quit: return "xmark.circle"
        case .forceQuit: return "xmark.circle.fill"
        case .copyPID: return "doc.on.clipboard"
        case .copyPath: return "doc.on.clipboard"
        case .openActivityMonitor: return "chart.bar.xaxis"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .quit, .forceQuit: return true
        default: return false
        }
    }
}

/// Result of a process action
struct ProcessActionResult {
    let success: Bool
    let message: String
    let sampleOutput: String?

    static func success(_ message: String, sampleOutput: String? = nil) -> ProcessActionResult {
        ProcessActionResult(success: true, message: message, sampleOutput: sampleOutput)
    }

    static func failure(_ message: String) -> ProcessActionResult {
        ProcessActionResult(success: false, message: message, sampleOutput: nil)
    }
}

/// Handles process actions
class ProcessActions {
    static let shared = ProcessActions()

    private init() {}

    /// Perform an action on a process
    func perform(_ action: ProcessAction, on process: ProcessInfoModel) async -> ProcessActionResult {
        switch action {
        case .revealInFinder:
            return revealInFinder(process)

        case .sample:
            return await sampleProcess(process)

        case .quit:
            return quitProcess(process, force: false)

        case .forceQuit:
            return quitProcess(process, force: true)

        case .copyPID:
            return copyPID(process)

        case .copyPath:
            return copyPath(process)

        case .openActivityMonitor:
            return openActivityMonitor()
        }
    }

    /// Check if an action is available for a process
    func isAvailable(_ action: ProcessAction, for process: ProcessInfoModel) -> Bool {
        switch action {
        case .revealInFinder:
            return process.path != nil

        case .sample:
            return true

        case .quit, .forceQuit:
            // Can't quit kernel processes or root-owned processes without privileges
            return process.user == NSUserName() || process.user == NSFullUserName()

        case .copyPID:
            return true

        case .copyPath:
            return process.path != nil

        case .openActivityMonitor:
            return true
        }
    }

    // MARK: - Action Implementations

    private func revealInFinder(_ process: ProcessInfoModel) -> ProcessActionResult {
        guard let path = process.path ?? process.appBundlePath else {
            return .failure("Process path not available")
        }

        let url = URL(fileURLWithPath: path)

        // Check if it's an app bundle
        if let appPath = process.appBundlePath {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: appPath)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }

        return .success("Revealed \(process.name) in Finder")
    }

    private func sampleProcess(_ process: ProcessInfoModel) async -> ProcessActionResult {
        // Use sample command to profile the process
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sample")
        task.arguments = [String(process.id), "1", "-file", "/dev/stdout"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()

            return await withCheckedContinuation { continuation in
                task.terminationHandler = { _ in
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? "No output"

                    if task.terminationStatus == 0 {
                        continuation.resume(returning: .success(
                            "Sampled \(process.name) (PID: \(process.id))",
                            sampleOutput: output
                        ))
                    } else {
                        continuation.resume(returning: .failure("Failed to sample process: \(output)"))
                    }
                }
            }
        } catch {
            return .failure("Failed to start sample: \(error.localizedDescription)")
        }
    }

    private func quitProcess(_ process: ProcessInfoModel, force: Bool) -> ProcessActionResult {
        let signal: Int32 = force ? SIGKILL : SIGTERM

        let result = kill(process.id, signal)

        if result == 0 {
            let action = force ? "Force quit" : "Quit signal sent to"
            return .success("\(action) \(process.name) (PID: \(process.id))")
        } else {
            let errorMsg: String
            switch errno {
            case EPERM:
                errorMsg = "Permission denied"
            case ESRCH:
                errorMsg = "Process not found"
            default:
                errorMsg = "Error \(errno)"
            }
            return .failure("Failed to quit \(process.name): \(errorMsg)")
        }
    }

    private func copyPID(_ process: ProcessInfoModel) -> ProcessActionResult {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(String(process.id), forType: .string)
        return .success("Copied PID \(process.id) to clipboard")
    }

    private func copyPath(_ process: ProcessInfoModel) -> ProcessActionResult {
        guard let path = process.path else {
            return .failure("Process path not available")
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        return .success("Copied path to clipboard")
    }

    private func openActivityMonitor() -> ProcessActionResult {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")

        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                print("Failed to open Activity Monitor: \(error.localizedDescription)")
            }
        }
        return .success("Opened Activity Monitor")
    }
}

// MARK: - Sample Viewer Window

/// A window to display process sample output
class SampleViewerWindow: NSWindow {
    private let textView: NSTextView

    init(process: ProcessInfoModel, sampleOutput: String) {
        let frame = NSRect(x: 0, y: 0, width: 700, height: 500)

        textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.string = sampleOutput

        let scrollView = NSScrollView(frame: frame)
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        super.init(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        self.title = "Sample: \(process.name) (PID: \(process.id))"
        self.contentView = scrollView
        self.center()
    }
}
