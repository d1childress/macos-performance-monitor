# Operator

A native macOS system performance monitor built with Swift and SwiftUI. Operator provides comprehensive real-time monitoring of CPU, memory, disk, network, battery, and thermal metrics in a beautiful, modern interface.

## Features

### Dashboard Overview
- Real-time system metrics at a glance
- Circular gauges for CPU and memory usage
- Sparkline graphs showing historical trends
- System info header with model name, macOS version, and uptime
- Top processes quick view
- Disk usage per volume with visual progress bars
- Network interface status with IP addresses

### CPU Monitoring
- Total CPU usage with semi-circular gauge
- Physical and logical core counts
- Per-core usage visualization with circular indicators
- CPU history chart with smooth interpolation
- Idle percentage and frequency (when available)
- Color-coded status indicators (green/blue/yellow/red)

### Memory Monitoring
- RAM usage gauge with GB values
- Memory breakdown pie chart:
  - Active, Inactive, Wired, Compressed, Free
- Historical memory usage chart
- Swap memory monitoring with usage bar
- Average usage statistics

### Network Monitoring
- Upload/download speed gauges
- Real-time network history graphs
- Active network interfaces list
- Connection status indicators
- Per-interface statistics

### Network Diagnostics
- **Ping**: Test connectivity to hosts with configurable count
- **NSLookup**: DNS resolution lookup
- **Whois**: Domain registration information
- Copy results to clipboard
- Success/error status indicators

### Process Management
- Sortable process table (by CPU, Memory, Name, PID)
- Search/filter processes by name, PID, or user
- Quick filter by process state (Running, Sleeping, Stopped, Zombie)
- Process context menu actions:
  - Reveal in Finder
  - Sample process
  - Copy PID / Copy path
  - Open Activity Monitor
  - Quit / Force Quit
- Per-process CPU and memory usage bars
- Thread count display

### Battery & Thermal
- Battery charge gauge with percentage
- Charging status and power draw (watts)
- Time remaining estimate
- Battery health percentage and cycle count
- Design vs current capacity comparison
- Thermal pressure indicator (Nominal/Fair/Serious/Critical)
- CPU and GPU temperature graphs
- Fan speed monitoring with animated indicators

### History & Export
- Historical trends with selectable time ranges:
  - Last Hour, Last 6 Hours, Last 24 Hours, Last 7 Days
- Metric selector (CPU, Memory, Network, Disk I/O)
- Statistics panel with averages and maximums
- Session reports with duration and performance summaries
- Export options:
  - CSV format
  - JSON format
  - Copy summary to clipboard

### Alert System
- Configurable alert rules:
  - High CPU Usage
  - Sustained CPU Usage
  - High Memory Usage
  - Memory Pressure
  - Network Disconnected
  - High Upload/Download Speed
  - Low Disk Space
  - Process High CPU/Memory
- macOS native notifications
- Cooldown period configuration
- Anomaly detection using statistical analysis
- Alert history with read/unread tracking

### Settings & Customization
- **General**: Refresh interval, history length, launch at login
- **Profiles**: Built-in profiles (Default, Power Saver, Performance, Developer) and custom profiles
- **Appearance**: Light/Dark/System theme, accent color selection
- **Menu Bar**: Display mode (Icon/Network Speeds/CPU), text density
- **Alerts**: Enable/disable rules, configure thresholds

### Menu Bar Integration
- Quick access to system metrics from the menu bar
- Customizable display showing network speeds or CPU usage
- Compact dropdown with key statistics

### Onboarding
- First-launch welcome flow
- Feature highlights with smooth transitions
- Notification permission request

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building from source)

## Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/d1childress/macos-performance-monitor.git
   cd macos-performance-monitor/Operator
   ```

2. Open the project in Xcode:
   ```bash
   open Operator.xcodeproj
   ```

   Or build with Swift Package Manager:
   ```bash
   swift build
   ```

3. Build and run (Cmd+R) or archive for distribution (Product > Archive)

## Architecture

```
Operator/
├── App/
│   ├── OperatorApp.swift       # App entry point
│   └── AppDelegate.swift       # App lifecycle management
├── Models/
│   ├── SystemMetrics.swift     # Data models for all metrics
│   └── ProcessInfo.swift       # Process data model
├── Services/
│   ├── SystemMonitor.swift     # Main monitoring coordinator
│   ├── CPUMonitor.swift        # CPU metrics collection
│   ├── MemoryMonitor.swift     # Memory metrics collection
│   ├── DiskMonitor.swift       # Disk I/O and volume monitoring
│   ├── NetworkMonitor.swift    # Network interface monitoring
│   ├── BatteryMonitor.swift    # Battery and power monitoring
│   ├── ProcessMonitor.swift    # Process enumeration
│   ├── ProcessActions.swift    # Process management actions
│   ├── NetworkDiagnostics.swift # Ping, nslookup, whois
│   ├── AlertManager.swift      # Alert rules and notifications
│   ├── HistoryStore.swift      # Historical data persistence
│   └── ProfileManager.swift    # Usage profiles management
├── Views/
│   ├── MainWindow/
│   │   ├── ContentView.swift   # Main window with tab navigation
│   │   ├── OverviewView.swift  # Dashboard view
│   │   ├── CPUView.swift       # CPU details view
│   │   ├── MemoryView.swift    # Memory details view
│   │   ├── NetworkView.swift   # Network details view
│   │   ├── NetworkDiagnosticsView.swift # Diagnostics tools
│   │   ├── ProcessesView.swift # Process table view
│   │   ├── BatteryView.swift   # Battery/thermal view
│   │   └── HistoryView.swift   # History and export view
│   ├── Components/
│   │   ├── GlassPanel.swift    # Frosted glass card component
│   │   ├── GaugeView.swift     # Circular/semi-circular gauges
│   │   ├── SparklineView.swift # Mini trend graphs
│   │   ├── NetworkGraphView.swift # Network activity graphs
│   │   └── CustomToolbar.swift # Custom toolbar buttons
│   ├── MenuBar/
│   │   └── MenuBarView.swift   # Menu bar extra UI
│   ├── Settings/
│   │   └── SettingsView.swift  # Preferences window
│   └── Onboarding/
│       └── OnboardingView.swift # First-launch experience
└── Utilities/
    ├── Formatters.swift        # Byte, percent, speed formatters
    ├── MachHelpers.swift       # Low-level Mach API wrappers
    └── SysctlWrapper.swift     # sysctl system calls
```

## Tech Stack

- **Swift 5.9+** with strict concurrency
- **SwiftUI** for declarative UI
- **SwiftCharts** for data visualization
- **Combine** for reactive data flow
- **UserNotifications** for native alerts
- **Mach APIs** for low-level system metrics
- **IOKit** for battery and thermal data

## Python TUI Version

This repository also includes a Python-based terminal UI version (`macos_tui_advanced.py`) for command-line monitoring:

```bash
# Install dependencies
pip install -r requirements.txt

# Run the TUI
python3 macos_tui_advanced.py

# Continuous monitoring
python3 macos_tui_advanced.py -c -i 2

# JSON output
python3 macos_tui_advanced.py -j
```

## License

MIT License - Feel free to use and modify.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
