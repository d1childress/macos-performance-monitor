//
//  ProcessesView.swift
//  Operator
//
//  Sortable process table view with actions.
//

import SwiftUI

struct ProcessesView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @State private var sortKey: ProcessSortKey = .cpu
    @State private var sortAscending = false
    @State private var searchText = ""
    @State private var selectedProcess: ProcessInfoModel?
    @State private var showActionResult: ProcessActionResult?
    @State private var showSampleOutput: String?
    @State private var filterState: ProcessState?
    @State private var showQuickFilters = false

    private var filteredProcesses: [ProcessInfoModel] {
        var processes = systemMonitor.processes

        // Filter by search text
        if !searchText.isEmpty {
            processes = processes.filter { process in
                process.name.localizedCaseInsensitiveContains(searchText) ||
                String(process.id).contains(searchText) ||
                process.user.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by state
        if let state = filterState {
            processes = processes.filter { $0.state == state }
        }

        // Sort
        processes.sort { lhs, rhs in
            let result: Bool
            switch sortKey {
            case .cpu:
                result = lhs.cpuUsage > rhs.cpuUsage
            case .memory:
                result = lhs.memoryUsage > rhs.memoryUsage
            case .name:
                result = lhs.name.lowercased() < rhs.name.lowercased()
            case .pid:
                result = lhs.id < rhs.id
            }
            return sortAscending ? !result : result
        }

        return processes
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 16) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search processes...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .allowsHitTesting(true)
                    }
                }
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .frame(width: 250)

                // Quick filters toggle
                Button {
                    withAnimation {
                        showQuickFilters.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Filters")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(minHeight: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundColor(filterState != nil ? .accentColor : .secondary)
                .allowsHitTesting(true)

                Spacer()

                // Sort options
                HStack(spacing: 8) {
                    Text("Sort by:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(ProcessSortKey.allCases, id: \.self) { key in
                        SortButton(
                            key: key,
                            isSelected: sortKey == key,
                            isAscending: sortAscending
                        ) {
                            if sortKey == key {
                                sortAscending.toggle()
                            } else {
                                sortKey = key
                                sortAscending = false
                            }
                        }
                    }
                }

                // Process count
                Text("\(filteredProcesses.count) processes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)

            // Quick filters bar
            if showQuickFilters {
                QuickFiltersBar(filterState: $filterState)
            }

            Divider()

            // Table header
            HStack(spacing: 0) {
                TableHeader(title: "PID", width: 60, sortKey: .pid, currentSort: sortKey, ascending: sortAscending) {
                    toggleSort(.pid)
                }
                TableHeader(title: "Name", width: nil, sortKey: .name, currentSort: sortKey, ascending: sortAscending) {
                    toggleSort(.name)
                }
                TableHeader(title: "User", width: 100, sortKey: nil, currentSort: sortKey, ascending: sortAscending) {}
                TableHeader(title: "CPU %", width: 80, sortKey: .cpu, currentSort: sortKey, ascending: sortAscending) {
                    toggleSort(.cpu)
                }
                TableHeader(title: "Memory", width: 100, sortKey: .memory, currentSort: sortKey, ascending: sortAscending) {
                    toggleSort(.memory)
                }
                TableHeader(title: "Threads", width: 70, sortKey: nil, currentSort: sortKey, ascending: sortAscending) {}
                TableHeader(title: "State", width: 80, sortKey: nil, currentSort: sortKey, ascending: sortAscending) {}
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05))

            Divider()

            // Process list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredProcesses) { process in
                        ProcessRow(
                            process: process,
                            isSelected: selectedProcess?.id == process.id,
                            onAction: { action in
                                performAction(action, on: process)
                            }
                        )
                        .onTapGesture {
                            selectedProcess = process
                        }

                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
        }
        .alert("Process Action", isPresented: .init(
            get: { showActionResult != nil },
            set: { if !$0 { showActionResult = nil } }
        )) {
            Button("OK") { showActionResult = nil }
        } message: {
            if let result = showActionResult {
                Text(result.message)
            }
        }
        .sheet(isPresented: .init(
            get: { showSampleOutput != nil },
            set: { if !$0 { showSampleOutput = nil } }
        )) {
            SampleOutputView(
                processName: selectedProcess?.name ?? "Process",
                output: showSampleOutput ?? ""
            )
        }
    }

    private func toggleSort(_ key: ProcessSortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = false
        }
    }

    private func performAction(_ action: ProcessAction, on process: ProcessInfoModel) {
        Task {
            let result = await ProcessActions.shared.perform(action, on: process)
            await MainActor.run {
                if let sampleOutput = result.sampleOutput {
                    self.showSampleOutput = sampleOutput
                } else {
                    self.showActionResult = result
                }
            }
        }
    }
}

// MARK: - Quick Filters Bar

struct QuickFiltersBar: View {
    @Binding var filterState: ProcessState?

    var body: some View {
        HStack(spacing: 8) {
            Text("State:")
                .font(.caption)
                .foregroundColor(.secondary)

            FilterPill(
                title: "All",
                isSelected: filterState == nil,
                color: .accentColor
            ) {
                filterState = nil
            }

            ForEach([ProcessState.running, .sleeping, .stopped, .zombie], id: \.self) { state in
                FilterPill(
                    title: state.rawValue,
                    isSelected: filterState == state,
                    color: stateColor(state)
                ) {
                    filterState = state
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private func stateColor(_ state: ProcessState) -> Color {
        switch state {
        case .running: return .green
        case .sleeping: return .blue
        case .stopped: return .orange
        case .zombie: return .red
        case .unknown: return .gray
        }
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .frame(minHeight: 24)
                .background(isSelected ? color.opacity(0.2) : Color.clear)
                .foregroundColor(isSelected ? color : .secondary)
                .cornerRadius(12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .allowsHitTesting(true)
    }
}

// MARK: - Sort Button

struct SortButton: View {
    let key: ProcessSortKey
    let isSelected: Bool
    let isAscending: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: key.icon)
                    .font(.system(size: 10))
                Text(key.rawValue)
                    .font(.caption)

                if isSelected {
                    Image(systemName: isAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 28)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .allowsHitTesting(true)
    }
}

// MARK: - Table Header

struct TableHeader: View {
    let title: String
    let width: CGFloat?
    let sortKey: ProcessSortKey?
    let currentSort: ProcessSortKey
    let ascending: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)

                if let sortKey = sortKey, sortKey == currentSort {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
            }
            .foregroundColor(sortKey == currentSort ? .accentColor : .secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .allowsHitTesting(true)
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil)
    }
}

// MARK: - Process Row

struct ProcessRow: View {
    let process: ProcessInfoModel
    let isSelected: Bool
    let onAction: (ProcessAction) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // PID
            Text(String(process.id))
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)

            // Name
            HStack(spacing: 8) {
                ProcessIcon(name: process.name)

                Text(process.name)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // User
            Text(process.user)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)

            // CPU %
            HStack(spacing: 4) {
                ProgressBarView(
                    value: min(process.cpuUsage, 100),
                    status: process.cpuStatusColor,
                    height: 4
                )
                .frame(width: 40)

                Text(PercentFormatter.format(process.cpuUsage, decimals: 1))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(process.cpuStatusColor.swiftUIColor)
            }
            .frame(width: 80, alignment: .trailing)

            // Memory
            VStack(alignment: .trailing, spacing: 2) {
                Text(process.formattedMemory)
                    .font(.caption)
                    .monospacedDigit()
                Text(PercentFormatter.format(process.memoryUsage, decimals: 1))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100, alignment: .trailing)

            // Threads
            Text(String(process.threads))
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)

            // State
            HStack(spacing: 4) {
                Image(systemName: process.state.icon)
                    .font(.system(size: 10))
                    .foregroundColor(stateColor)
                Text(process.state.rawValue)
                    .font(.caption2)
            }
            .frame(width: 80, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .frame(height: 28)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contextMenu {
            ProcessContextMenu(process: process, onAction: onAction)
        }
    }

    private var stateColor: Color {
        switch process.state {
        case .running: return .green
        case .sleeping: return .blue
        case .stopped: return .orange
        case .zombie: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Process Context Menu

struct ProcessContextMenu: View {
    let process: ProcessInfoModel
    let onAction: (ProcessAction) -> Void

    var body: some View {
        Group {
            if ProcessActions.shared.isAvailable(.revealInFinder, for: process) {
                Button {
                    onAction(.revealInFinder)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
            }

            Button {
                onAction(.sample)
            } label: {
                Label("Sample Process", systemImage: "waveform.path.ecg")
            }

            Divider()

            Button {
                onAction(.copyPID)
            } label: {
                Label("Copy PID", systemImage: "doc.on.clipboard")
            }

            if ProcessActions.shared.isAvailable(.copyPath, for: process) {
                Button {
                    onAction(.copyPath)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.clipboard")
                }
            }

            Divider()

            Button {
                onAction(.openActivityMonitor)
            } label: {
                Label("Open Activity Monitor", systemImage: "chart.bar.xaxis")
            }

            if ProcessActions.shared.isAvailable(.quit, for: process) {
                Divider()

                Button(role: .destructive) {
                    onAction(.quit)
                } label: {
                    Label("Quit", systemImage: "xmark.circle")
                }

                Button(role: .destructive) {
                    onAction(.forceQuit)
                } label: {
                    Label("Force Quit", systemImage: "xmark.circle.fill")
                }
            }
        }
    }
}

// MARK: - Sample Output View

struct SampleOutputView: View {
    let processName: String
    let output: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sample: \(processName)")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding()

            Divider()

            ScrollView {
                Text(output)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(width: 700, height: 500)
    }
}

// MARK: - Process Icon

struct ProcessIcon: View {
    let name: String

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .frame(width: 20, height: 20)
    }

    private var iconName: String {
        let lowercaseName = name.lowercased()

        if lowercaseName.contains("safari") { return "safari" }
        if lowercaseName.contains("finder") { return "folder" }
        if lowercaseName.contains("mail") { return "envelope" }
        if lowercaseName.contains("music") || lowercaseName.contains("spotify") { return "music.note" }
        if lowercaseName.contains("chrome") || lowercaseName.contains("firefox") { return "globe" }
        if lowercaseName.contains("terminal") || lowercaseName.contains("iterm") { return "terminal" }
        if lowercaseName.contains("xcode") { return "hammer" }
        if lowercaseName.contains("docker") { return "shippingbox" }
        if lowercaseName.contains("slack") || lowercaseName.contains("discord") { return "message" }
        if lowercaseName.contains("zoom") { return "video" }
        if lowercaseName.contains("kernel") || lowercaseName.contains("launchd") { return "gearshape.2" }

        return "app"
    }
}

// MARK: - Preview

#Preview {
    ProcessesView()
        .environmentObject(SystemMonitor())
        .frame(width: 900, height: 600)
}
