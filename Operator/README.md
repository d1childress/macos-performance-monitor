# Operator

A native macOS performance monitoring application with menu bar integration, built with SwiftUI and Swift Charts.

## Features

- **Menu Bar Integration**: Live network speeds or CPU usage displayed in the menu bar
- **Real-time Monitoring**: CPU, Memory, Network, Disk, and Process monitoring
- **Liquid Glass UI**: Modern macOS design with vibrancy effects
- **Light/Dark Mode**: Full support for system appearance
- **Network Focus**: Per-interface breakdown, connection status, bandwidth graphs
- **Process Manager**: Sortable, searchable process list

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

## Building

### Using Xcode

1. Open `Operator.xcodeproj` in Xcode
2. Select the Operator scheme
3. Build and run (Cmd+R)

### Using Swift Package Manager

```bash
cd Operator
swift build
swift run
```

## Project Structure

```
Operator/
├── App/                    # App entry point and delegate
├── Views/
│   ├── MainWindow/         # Tab views (Overview, CPU, Memory, Network, Processes)
│   ├── MenuBar/            # Menu bar popover
│   ├── Settings/           # Preferences window
│   └── Components/         # Reusable UI components
├── Models/                 # Data models
├── Services/               # System monitoring services
├── Utilities/              # Helpers (sysctl, Mach, formatters)
└── Resources/              # Assets and configuration
```

## System APIs Used

| Metric | API |
|--------|-----|
| CPU Usage | `host_processor_info()` |
| Memory | `vm_statistics64` |
| Network I/O | `getifaddrs()` |
| Network Status | `NWPathMonitor` |
| Disk I/O | IOKit |
| Processes | `libproc` |
| System Info | `sysctl` |

## Creating a DMG

To create a distributable DMG:

```bash
# Build release version
xcodebuild -scheme Operator -configuration Release

# Create DMG (requires create-dmg tool)
brew install create-dmg
create-dmg \
  --volname "Operator" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --app-drop-link 425 178 \
  "Operator.dmg" \
  "build/Release/Operator.app"
```

## License

MIT License
