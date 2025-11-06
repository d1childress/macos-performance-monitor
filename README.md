# macOS Performance Monitor 🖥️

A beautiful and comprehensive system performance monitoring tool for macOS with an enhanced terminal UI featuring colors, progress bars, sparklines, and real-time updates.

## ✨ Features

### 📊 Core Monitoring
- **CPU Usage**: Overall and per-core monitoring with color-coded status indicators
- **Memory Usage**: RAM and swap tracking with visual progress bars
- **Disk I/O**: Multi-partition monitoring with read/write statistics
- **Network I/O**: Upload/download tracking with rate calculations
- **Process Information**: Top processes by CPU or memory usage
- **Battery Status**: Level, charging state, and time remaining
- **Temperature Monitoring**: CPU temperature (requires sudo for powermetrics)
- **System Uptime**: Boot time and uptime tracking

### 🎨 Enhanced UI/UX
- **Color-Coded Indicators**: Visual status (🟢 green, 🟡 yellow, 🔴 red) based on usage thresholds
  - Green: < 50% usage
  - Blue: 50-75% usage
  - Yellow: 75-90% usage
  - Red: > 90% usage
- **Progress Bars**: Beautiful visual representations of resource usage
- **Sparklines**: Historical trend graphs for CPU, memory, and network activity
- **Rich Tables**: Formatted tables for process information with colored bars
- **Panels & Borders**: Organized sections with rounded borders
- **Side-by-Side Layout**: Efficient use of terminal space with multi-column layout
- **Historical Tracking**: Tracks last 20 data points for trend visualization

### 🔧 Output Options
- **Terminal Display**: Beautiful formatted output with Rich library
- **JSON Export**: Machine-readable output for integration
- **NDJSON Streaming**: Newline-delimited JSON for continuous logging
- **File Output**: Save reports to files
- **Continuous Mode**: Real-time updates at configurable intervals
- **Compact Mode**: Condensed vertical layout for smaller terminals

## 📋 Requirements

```bash
pip install -r requirements.txt
```

### Dependencies
- `psutil>=5.9.0` - System and process utilities
- `rich>=13.0.0` - Terminal UI enhancements
- `matplotlib>=3.7.0` - Optional visualization support
- `numpy>=1.24.0` - Optional data analysis support

## 🚀 Usage

### Basic Usage
```bash
# Single snapshot
python3 macos_performance_monitor.py

# Continuous monitoring (updates every 5 seconds)
python3 macos_performance_monitor.py -c

# Custom update interval (every 2 seconds)
python3 macos_performance_monitor.py -c -i 2

# Run for specific duration (60 seconds)
python3 macos_performance_monitor.py -c --duration 60
```

### Display Options
```bash
# Compact mode (vertical layout)
python3 macos_performance_monitor.py --compact

# Show more processes (top 20)
python3 macos_performance_monitor.py --top 20

# Sort by memory instead of CPU
python3 macos_performance_monitor.py --sort-by memory

# Hide specific sections
python3 macos_performance_monitor.py --no-processes --no-battery

# Disable screen clearing in continuous mode
python3 macos_performance_monitor.py -c --no-clear
```

### Output Formats
```bash
# JSON output
python3 macos_performance_monitor.py -j

# NDJSON streaming
python3 macos_performance_monitor.py -c --ndjson

# Save to file
python3 macos_performance_monitor.py -c --out performance.log

# Save continuous JSON to file
python3 macos_performance_monitor.py -c --ndjson --out performance.jsonl
```

### Advanced Features
```bash
# Enable temperature monitoring (requires sudo access)
python3 macos_performance_monitor.py --temps

# Full featured continuous monitoring
python3 macos_performance_monitor.py -c -i 3 --temps --top 15
```

## 🎯 Command Line Arguments

| Argument | Description |
|----------|-------------|
| `-j`, `--json` | Output as JSON |
| `--ndjson` | Stream as newline-delimited JSON |
| `--out FILE` | Write output to file |
| `-c`, `--continuous` | Run continuously |
| `-i`, `--interval` | Update interval in seconds (default: 5) |
| `--duration` | Total duration to run in seconds |
| `--temps` | Enable temperature monitoring (requires sudo) |
| `--no-processes` | Hide process information |
| `--no-disk-io` | Hide disk I/O statistics |
| `--no-battery` | Hide battery information |
| `--top N` | Number of processes to display (default: 10) |
| `--sort-by` | Sort processes by `cpu` or `memory` (default: cpu) |
| `--no-clear` | Don't clear screen on updates |
| `--compact` | Use compact vertical layout |

## 🎨 UI Preview

The tool displays information in beautifully formatted panels:

```
╔══════════════════════════════════════════════════════════════╗
║  🖥️  macOS System Performance Monitor                        ║
║  📅 2024-01-15 14:30:45                                      ║
╚══════════════════════════════════════════════════════════════╝

╭─ System Uptime ─────────────────────────────────────────────╮
│ ⏰ Boot Time: 2024-01-14 08:00:00                           │
│ ⏱️  Uptime: 1d 6h 30m                                        │
╰─────────────────────────────────────────────────────────────╯

╭─ 🖥️  CPU Usage ──────────╮  ╭─ 💾 Memory Usage ──────────╮
│ 🟢 Overall: 45.2%        │  │ 🟡 Usage: 72.3%           │
│ ████████████░░░░░░░░░░░░ │  │ ██████████████████░░░░░░░ │
│ 📊 Trend: ▃▄▅▆▅▄▃▄▅▆    │  │ 📊 Trend: ▆▆▇▇▇▆▆▇█▇    │
│ 🔢 Cores: 8 physical     │  │ 📦 Used: 23.5 / 32.0 GiB │
│ ⚡ Frequency: 2400 MHz    │  │ ✨ Available: 8.5 GiB     │
╰──────────────────────────╯  ╰───────────────────────────╯
```

## 💡 Tips

1. **Temperature Monitoring**: To enable temperature monitoring, you need to pre-authorize sudo access to powermetrics:
   ```bash
   sudo powermetrics --samplers smc -i 1 -n 1
   ```

2. **Continuous Monitoring**: Use `-c` flag with `--no-clear` if you want to keep historical output in your terminal

3. **Log Analysis**: Use `--ndjson` with `--out` for easy log parsing with tools like `jq`:
   ```bash
   python3 macos_performance_monitor.py -c --ndjson --out perf.jsonl
   cat perf.jsonl | jq '.cpu.overall_usage'
   ```

4. **Performance**: The tool is lightweight and has minimal system overhead

## 🖥️ Platform

macOS only (requires macOS-specific system APIs)

## 📝 License

MIT License - Feel free to use and modify
