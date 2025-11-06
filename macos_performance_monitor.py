#!/usr/bin/env python3
"""
macOS System Performance Monitor
Monitors CPU, memory, disk, network, and process information
"""

import psutil
import subprocess
import json
import time
from datetime import datetime
from collections import defaultdict, deque
from typing import Any, Dict, List, Optional

# Rich library imports for enhanced UI
from rich.console import Console
from rich.table import Table
from rich.progress import Progress, BarColumn, TextColumn
from rich.panel import Panel
from rich.columns import Columns
from rich.layout import Layout
from rich import box
from rich.text import Text
from rich.live import Live


class MacOSPerformanceMonitor:
    def __init__(self):
        self.start_time = time.time()
        self.network_io_start = psutil.net_io_counters()
        # Snapshot state for instantaneous rates
        self._prev_net_io = self.network_io_start
        self._prev_disk_io = psutil.disk_io_counters()
        self._prev_sample_ts = self.start_time
        # Temperature cache
        self._last_temp = None
        self._last_temp_ts = 0.0
        self.enable_temps = False
        self.temp_refresh_seconds = 5
        # Process CPU priming
        self._proc_prime_ts = 0.0
        # Prime cpu_percent to enable non-blocking reads
        try:
            psutil.cpu_percent(interval=None)
            psutil.cpu_percent(interval=None, percpu=True)
        except Exception:
            pass

        # Rich console for enhanced output
        self.console = Console()

        # Historical data tracking for trends
        self.history_size = 20
        self.cpu_history = deque(maxlen=self.history_size)
        self.memory_history = deque(maxlen=self.history_size)
        self.network_history = deque(maxlen=self.history_size)

    def _get_status_color(self, percent: float) -> str:
        """Return color based on usage percentage"""
        if percent >= 90:
            return "red"
        elif percent >= 75:
            return "yellow"
        elif percent >= 50:
            return "blue"
        else:
            return "green"

    def _get_status_emoji(self, percent: float) -> str:
        """Return emoji based on usage percentage"""
        if percent >= 90:
            return "🔴"
        elif percent >= 75:
            return "🟡"
        else:
            return "🟢"

    def _create_progress_bar(self, value: float, width: int = 20) -> str:
        """Create a text-based progress bar"""
        filled = int((value / 100) * width)
        bar = "█" * filled + "░" * (width - filled)
        return bar

    def _format_bytes(self, bytes_val: float, suffix: str = "B") -> str:
        """Format bytes to human readable format"""
        for unit in ["", "K", "M", "G", "T"]:
            if abs(bytes_val) < 1024.0:
                return f"{bytes_val:3.1f}{unit}{suffix}"
            bytes_val /= 1024.0
        return f"{bytes_val:.1f}P{suffix}"

    def _create_sparkline(self, data: list, width: int = 15) -> str:
        """Create a simple sparkline from historical data"""
        if not data or len(data) < 2:
            return "─" * width

        bars = "▁▂▃▄▅▆▇█"
        min_val = min(data)
        max_val = max(data)
        range_val = max_val - min_val if max_val > min_val else 1

        result = []
        step = len(data) / width
        for i in range(width):
            idx = int(i * step)
            if idx < len(data):
                normalized = (data[idx] - min_val) / range_val
                bar_idx = min(int(normalized * len(bars)), len(bars) - 1)
                result.append(bars[bar_idx])
            else:
                result.append("─")

        return "".join(result)
        
    def get_cpu_info(self) -> Dict[str, Any]:
        """Get detailed CPU information"""
        cpu_percent = psutil.cpu_percent(interval=None, percpu=True)
        cpu_freq = psutil.cpu_freq()
        
        return {
            "overall_usage": psutil.cpu_percent(interval=None),
            "per_core_usage": cpu_percent,
            "core_count": psutil.cpu_count(logical=False),
            "thread_count": psutil.cpu_count(logical=True),
            "frequency_mhz": cpu_freq.current if cpu_freq else None,
            "max_frequency_mhz": cpu_freq.max if cpu_freq else None,
        }
    
    def get_memory_info(self) -> Dict[str, Any]:
        """Get memory usage information"""
        mem = psutil.virtual_memory()
        swap = psutil.swap_memory()
        
        return {
            "total_gb": round(mem.total / (1024**3), 2),
            "available_gb": round(mem.available / (1024**3), 2),
            "used_gb": round(mem.used / (1024**3), 2),
            "percent": mem.percent,
            "swap_total_gb": round(swap.total / (1024**3), 2),
            "swap_used_gb": round(swap.used / (1024**3), 2),
            "swap_percent": swap.percent,
        }
    
    def get_disk_info(self) -> Dict[str, Any]:
        """Get disk usage information"""
        partitions = psutil.disk_partitions()
        disk_info = []
        
        for partition in partitions:
            try:
                usage = psutil.disk_usage(partition.mountpoint)
                disk_info.append({
                    "device": partition.device,
                    "mountpoint": partition.mountpoint,
                    "fstype": partition.fstype,
                    "total_gib": round(usage.total / (1024**3), 2),
                    "used_gib": round(usage.used / (1024**3), 2),
                    "free_gib": round(usage.free / (1024**3), 2),
                    "percent": usage.percent,
                })
            except (PermissionError, FileNotFoundError):
                continue
        
        io = psutil.disk_io_counters()
        disk_io = None
        if io:
            now = time.time()
            dt = max(now - self._prev_sample_ts, 1e-6)
            prev = self._prev_disk_io
            read_rate_mib_s = (io.read_bytes - prev.read_bytes) / (1024**2) / dt
            write_rate_mib_s = (io.write_bytes - prev.write_bytes) / (1024**2) / dt
            disk_io = {
                "read_mib": round(io.read_bytes / (1024**2), 2),
                "write_mib": round(io.write_bytes / (1024**2), 2),
                "read_rate_mib_s": round(read_rate_mib_s, 2),
                "write_rate_mib_s": round(write_rate_mib_s, 2),
                "read_count": io.read_count,
                "write_count": io.write_count,
            }
            self._prev_disk_io = io
        
        return {"partitions": disk_info, "io_stats": disk_io}
    
    def get_network_info(self) -> Dict[str, Any]:
        """Get network usage information"""
        net_io = psutil.net_io_counters()
        
        # Calculate instantaneous rates based on previous snapshot
        now = time.time()
        dt = max(now - self._prev_sample_ts, 1e-6)
        sent_rate = (net_io.bytes_sent - self._prev_net_io.bytes_sent) / dt
        recv_rate = (net_io.bytes_recv - self._prev_net_io.bytes_recv) / dt
        self._prev_net_io = net_io
        self._prev_sample_ts = now
        
        return {
            "bytes_sent_mib": round(net_io.bytes_sent / (1024**2), 2),
            "bytes_recv_mib": round(net_io.bytes_recv / (1024**2), 2),
            "send_rate_mib_s": round(sent_rate / (1024**2), 2),
            "recv_rate_mib_s": round(recv_rate / (1024**2), 2),
            "packets_sent": net_io.packets_sent,
            "packets_recv": net_io.packets_recv,
        }
    
    def get_battery_info(self) -> Optional[Dict[str, Any]]:
        """Get battery information (if available)"""
        battery = psutil.sensors_battery()
        if battery:
            return {
                "percent": battery.percent,
                "plugged_in": battery.power_plugged,
                "time_left_minutes": battery.secsleft // 60 if battery.secsleft != psutil.POWER_TIME_UNLIMITED else None,
            }
        return None
    
    def get_temperature_info(self) -> Optional[Dict[str, Any]]:
        """Get temperature information using powermetrics (requires sudo). Respects --temps flag and caches results."""
        if not self.enable_temps:
            return None
        now = time.time()
        if now - self._last_temp_ts < self.temp_refresh_seconds and self._last_temp is not None:
            return self._last_temp
        try:
            result = subprocess.run(
                ['sudo', '-n', 'powermetrics', '--samplers', 'smc', '-i', '1', '-n', '1'],
                capture_output=True,
                text=True,
                timeout=3
            )
            if result.returncode == 0:
                temps = {}
                for line in result.stdout.split('\n'):
                    if 'CPU die temperature' in line:
                        try:
                            temp = line.split(':')[1].strip().replace(' C', '')
                            temps['cpu_temp_c'] = float(temp)
                        except Exception:
                            continue
                self._last_temp = temps if temps else None
                self._last_temp_ts = now
                return self._last_temp
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError, FileNotFoundError):
            return None
        return None
    
    def get_top_processes(self, num: int = 10, sort_by: str = 'cpu') -> List[Dict[str, Any]]:
        """Get top processes by CPU or memory usage"""
        # Prime process CPU metrics to avoid 0.0 readings
        now = time.time()
        if sort_by == 'cpu' and (now - self._proc_prime_ts > 5):
            for p in psutil.process_iter(['pid']):
                try:
                    p.cpu_percent(None)
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    continue
            time.sleep(0.2)
            self._proc_prime_ts = now

        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent', 'username']):
            try:
                cpu_pct = proc.info['cpu_percent'] or 0.0
                mem_pct = proc.info['memory_percent'] or 0.0
                
                processes.append({
                    'pid': proc.info['pid'],
                    'name': proc.info['name'],
                    'cpu_percent': cpu_pct,
                    'memory_percent': round(mem_pct, 2),
                    'username': proc.info['username'],
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
        
        if sort_by not in ('cpu', 'memory'):
            sort_by = 'cpu'
        if sort_by == 'cpu':
            processes.sort(key=lambda x: x['cpu_percent'], reverse=True)
        else:
            processes.sort(key=lambda x: x['memory_percent'], reverse=True)
        
        return processes[:num]
    
    def get_system_uptime(self) -> Dict[str, Any]:
        """Get system uptime"""
        boot_time = psutil.boot_time()
        uptime_seconds = time.time() - boot_time
        
        days = int(uptime_seconds // 86400)
        hours = int((uptime_seconds % 86400) // 3600)
        minutes = int((uptime_seconds % 3600) // 60)
        
        return {
            "boot_time": datetime.fromtimestamp(boot_time).strftime('%Y-%m-%d %H:%M:%S'),
            "uptime_days": days,
            "uptime_hours": hours,
            "uptime_minutes": minutes,
        }
    
    def print_performance_report(self, *, show_processes: bool = True, top_n: int = 10, sort_by: str = 'cpu', show_disk_io: bool = True, show_battery: bool = True, compact: bool = False) -> None:
        """Print a beautifully formatted performance report using Rich"""

        # Collect all data
        uptime = self.get_system_uptime()
        cpu = self.get_cpu_info()
        mem = self.get_memory_info()
        disk = self.get_disk_info()
        net = self.get_network_info()
        battery = self.get_battery_info() if show_battery else None
        temp = self.get_temperature_info()

        # Update historical data
        self.cpu_history.append(cpu['overall_usage'])
        self.memory_history.append(mem['percent'])
        self.network_history.append(net['send_rate_mib_s'] + net['recv_rate_mib_s'])

        # Create header panel
        title = Text()
        title.append("🖥️  macOS System Performance Monitor\n", style="bold cyan")
        title.append(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", style="dim")
        header = Panel(title, box=box.DOUBLE, border_style="bright_blue")
        self.console.print(header)

        # System Uptime Panel
        uptime_text = Text()
        uptime_text.append(f"⏰ Boot Time: ", style="bold")
        uptime_text.append(f"{uptime['boot_time']}\n", style="cyan")
        uptime_text.append(f"⏱️  Uptime: ", style="bold")
        uptime_text.append(f"{uptime['uptime_days']}d {uptime['uptime_hours']}h {uptime['uptime_minutes']}m", style="green")
        uptime_panel = Panel(uptime_text, title="[bold]System Uptime[/bold]", box=box.ROUNDED, border_style="green")

        # CPU Panel
        cpu_emoji = self._get_status_emoji(cpu['overall_usage'])
        cpu_color = self._get_status_color(cpu['overall_usage'])
        cpu_bar = self._create_progress_bar(cpu['overall_usage'], width=25)
        cpu_sparkline = self._create_sparkline(list(self.cpu_history), width=15)

        cpu_text = Text()
        cpu_text.append(f"{cpu_emoji} Overall: ", style="bold")
        cpu_text.append(f"{cpu['overall_usage']:.1f}%\n", style=f"bold {cpu_color}")
        cpu_text.append(f"{cpu_bar}\n", style=cpu_color)
        cpu_text.append(f"📊 Trend: {cpu_sparkline}\n\n", style="dim")
        cpu_text.append(f"🔢 Cores: ", style="bold")
        cpu_text.append(f"{cpu['core_count']} physical, {cpu['thread_count']} logical\n", style="white")

        if cpu['frequency_mhz']:
            cpu_text.append(f"⚡ Frequency: ", style="bold")
            if cpu['max_frequency_mhz']:
                cpu_text.append(f"{cpu['frequency_mhz']:.0f} MHz (Max: {cpu['max_frequency_mhz']:.0f} MHz)\n", style="yellow")
            else:
                cpu_text.append(f"{cpu['frequency_mhz']:.0f} MHz\n", style="yellow")

        # Per-core usage (compact representation)
        if len(cpu['per_core_usage']) <= 16:
            cpu_text.append(f"\n💻 Per-Core Usage:\n", style="bold")
            for i, core_usage in enumerate(cpu['per_core_usage']):
                core_color = self._get_status_color(core_usage)
                mini_bar = self._create_progress_bar(core_usage, width=10)
                cpu_text.append(f"  Core {i:2d}: ", style="dim")
                cpu_text.append(f"{mini_bar}", style=core_color)
                cpu_text.append(f" {core_usage:5.1f}%\n", style=core_color)

        cpu_panel = Panel(cpu_text, title="[bold]🖥️  CPU Usage[/bold]", box=box.ROUNDED, border_style=cpu_color)

        # Memory Panel
        mem_emoji = self._get_status_emoji(mem['percent'])
        mem_color = self._get_status_color(mem['percent'])
        mem_bar = self._create_progress_bar(mem['percent'], width=25)
        mem_sparkline = self._create_sparkline(list(self.memory_history), width=15)

        mem_text = Text()
        mem_text.append(f"{mem_emoji} Usage: ", style="bold")
        mem_text.append(f"{mem['percent']:.1f}%\n", style=f"bold {mem_color}")
        mem_text.append(f"{mem_bar}\n", style=mem_color)
        mem_text.append(f"📊 Trend: {mem_sparkline}\n\n", style="dim")
        mem_text.append(f"📦 Used: ", style="bold")
        mem_text.append(f"{mem['used_gb']:.2f} GiB / {mem['total_gb']:.2f} GiB\n", style="white")
        mem_text.append(f"✨ Available: ", style="bold")
        mem_text.append(f"{mem['available_gb']:.2f} GiB\n", style="green")

        if mem['swap_used_gb'] > 0:
            swap_color = self._get_status_color(mem['swap_percent'])
            mem_text.append(f"💾 Swap: ", style="bold")
            mem_text.append(f"{mem['swap_used_gb']:.2f} / {mem['swap_total_gb']:.2f} GiB ({mem['swap_percent']:.1f}%)", style=swap_color)

        mem_panel = Panel(mem_text, title="[bold]💾 Memory Usage[/bold]", box=box.ROUNDED, border_style=mem_color)

        # Disk Panel
        disk_text = Text()
        for idx, partition in enumerate(disk['partitions']):
            if idx > 0:
                disk_text.append("\n")
            disk_color = self._get_status_color(partition['percent'])
            disk_emoji = self._get_status_emoji(partition['percent'])
            disk_bar = self._create_progress_bar(partition['percent'], width=20)

            disk_text.append(f"{disk_emoji} {partition['mountpoint']}\n", style="bold cyan")
            disk_text.append(f"   {disk_bar} ", style=disk_color)
            disk_text.append(f"{partition['percent']:.1f}%\n", style=f"bold {disk_color}")
            disk_text.append(f"   {partition['used_gib']:.2f} / {partition['total_gib']:.2f} GiB ", style="white")
            disk_text.append(f"({partition['free_gib']:.2f} GiB free)\n", style="dim")

        if show_disk_io and disk['io_stats']:
            disk_text.append(f"\n📊 I/O Statistics:\n", style="bold")
            disk_text.append(f"   Read:  {disk['io_stats']['read_mib']:.2f} MiB ", style="blue")
            disk_text.append(f"({disk['io_stats']['read_rate_mib_s']:.2f} MiB/s)\n", style="dim")
            disk_text.append(f"   Write: {disk['io_stats']['write_mib']:.2f} MiB ", style="magenta")
            disk_text.append(f"({disk['io_stats']['write_rate_mib_s']:.2f} MiB/s)", style="dim")

        disk_panel = Panel(disk_text, title="[bold]💿 Disk Usage[/bold]", box=box.ROUNDED, border_style="blue")

        # Network Panel
        net_sparkline = self._create_sparkline(list(self.network_history), width=15)
        net_text = Text()
        net_text.append(f"📊 Activity: {net_sparkline}\n\n", style="dim")
        net_text.append(f"⬆️  Sent:     ", style="bold")
        net_text.append(f"{net['bytes_sent_mib']:.2f} MiB ", style="green")
        net_text.append(f"({net['send_rate_mib_s']:.2f} MiB/s)\n", style="dim")
        net_text.append(f"⬇️  Received: ", style="bold")
        net_text.append(f"{net['bytes_recv_mib']:.2f} MiB ", style="blue")
        net_text.append(f"({net['recv_rate_mib_s']:.2f} MiB/s)\n", style="dim")
        net_text.append(f"📦 Packets:   ", style="bold")
        net_text.append(f"↑{net['packets_sent']:,} / ↓{net['packets_recv']:,}", style="white")

        net_panel = Panel(net_text, title="[bold]🌐 Network[/bold]", box=box.ROUNDED, border_style="cyan")

        # Battery and Temperature Panel (combined)
        extra_panels = []

        if battery:
            battery_color = "green" if battery['percent'] > 50 else "yellow" if battery['percent'] > 20 else "red"
            battery_emoji = "🔌" if battery['plugged_in'] else "🔋"
            battery_bar = self._create_progress_bar(battery['percent'], width=15)

            battery_text = Text()
            battery_text.append(f"{battery_emoji} Level: ", style="bold")
            battery_text.append(f"{battery['percent']:.0f}%\n", style=f"bold {battery_color}")
            battery_text.append(f"{battery_bar}\n", style=battery_color)
            status = "Charging" if battery['plugged_in'] else "Discharging"
            battery_text.append(f"Status: {status}\n", style="cyan")
            if battery['time_left_minutes']:
                battery_text.append(f"⏱️  Time: {battery['time_left_minutes']} min", style="dim")

            battery_panel = Panel(battery_text, title="[bold]🔋 Battery[/bold]", box=box.ROUNDED, border_style=battery_color)
            extra_panels.append(battery_panel)

        if temp and 'cpu_temp_c' in temp:
            temp_val = temp['cpu_temp_c']
            temp_color = "red" if temp_val > 80 else "yellow" if temp_val > 60 else "green"

            temp_text = Text()
            temp_text.append(f"🌡️  CPU: ", style="bold")
            temp_text.append(f"{temp_val:.1f}°C", style=f"bold {temp_color}")

            temp_panel = Panel(temp_text, title="[bold]🌡️  Temperature[/bold]", box=box.ROUNDED, border_style=temp_color)
            extra_panels.append(temp_panel)

        # Top Processes Table
        if show_processes:
            table = Table(title=f"🔝 Top {top_n} Processes (by {'CPU' if sort_by == 'cpu' else 'Memory'})",
                         box=box.ROUNDED, border_style="magenta", show_header=True, header_style="bold magenta")

            table.add_column("PID", justify="right", style="cyan", no_wrap=True)
            table.add_column("CPU %", justify="right", style="yellow")
            table.add_column("CPU Bar", justify="left", width=12)
            table.add_column("MEM %", justify="right", style="blue")
            table.add_column("MEM Bar", justify="left", width=12)
            table.add_column("Process Name", style="white", overflow="fold")
            table.add_column("User", style="dim", overflow="fold")

            top_list = self.get_top_processes(num=top_n, sort_by=sort_by)
            for proc in top_list:
                cpu_pct = proc['cpu_percent']
                mem_pct = proc['memory_percent']
                cpu_bar = self._create_progress_bar(min(cpu_pct, 100), width=10)
                mem_bar = self._create_progress_bar(min(mem_pct, 100), width=10)

                cpu_color = self._get_status_color(cpu_pct)
                mem_color = self._get_status_color(mem_pct)

                table.add_row(
                    str(proc['pid']),
                    f"{cpu_pct:.1f}",
                    f"[{cpu_color}]{cpu_bar}[/{cpu_color}]",
                    f"{mem_pct:.1f}",
                    f"[{mem_color}]{mem_bar}[/{mem_color}]",
                    proc['name'][:40],
                    proc['username'][:15]
                )

        # Layout and print
        if not compact:
            # First row: uptime
            self.console.print(uptime_panel)

            # Second row: CPU and Memory side by side
            self.console.print(Columns([cpu_panel, mem_panel], equal=True, expand=True))

            # Third row: Disk and Network side by side
            self.console.print(Columns([disk_panel, net_panel], equal=True, expand=True))

            # Fourth row: Battery and Temperature (if available)
            if extra_panels:
                self.console.print(Columns(extra_panels, equal=True, expand=True))

            # Fifth row: Process table
            if show_processes:
                self.console.print(table)
        else:
            # Compact mode: stack everything
            self.console.print(uptime_panel)
            self.console.print(cpu_panel)
            self.console.print(mem_panel)
            self.console.print(disk_panel)
            self.console.print(net_panel)
            if extra_panels:
                for panel in extra_panels:
                    self.console.print(panel)
            if show_processes:
                self.console.print(table)
    
    def get_json_report(self, *, include_processes: bool = True, top_n: int = 10, sort_by: str = 'cpu', include_battery: bool = True) -> Dict[str, Any]:
        """Return performance data as JSON"""
        data = {
            "timestamp": datetime.now().isoformat(),
            "uptime": self.get_system_uptime(),
            "cpu": self.get_cpu_info(),
            "memory": self.get_memory_info(),
            "disk": self.get_disk_info(),
            "network": self.get_network_info(),
            "temperature": self.get_temperature_info(),
        }
        if include_battery:
            data["battery"] = self.get_battery_info()
        if include_processes:
            data["top_processes"] = self.get_top_processes(num=top_n, sort_by=sort_by)
        return data


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='macOS System Performance Monitor')
    parser.add_argument('-j', '--json', action='store_true', help='Output as JSON')
    parser.add_argument('--ndjson', action='store_true', help='Stream JSON as newline-delimited (one object per line)')
    parser.add_argument('--out', type=str, default=None, help='Write output to file (appends in continuous mode)')
    parser.add_argument('-c', '--continuous', action='store_true', help='Run continuously (updates every 5 seconds)')
    parser.add_argument('-i', '--interval', type=int, default=5, help='Update interval in seconds (default: 5)')
    parser.add_argument('--duration', type=int, default=None, help='Total duration to run in seconds')
    parser.add_argument('--temps', action='store_true', help='Collect temperatures (requires sudo powermetrics pre-auth)')
    parser.add_argument('--no-processes', action='store_true', help='Do not collect/show top processes')
    parser.add_argument('--no-disk-io', action='store_true', help='Hide disk I/O totals and rates')
    parser.add_argument('--no-battery', action='store_true', help='Hide battery section')
    parser.add_argument('--top', type=int, default=10, help='Number of processes to display (default: 10)')
    parser.add_argument('--sort-by', choices=['cpu', 'memory'], default='cpu', help='Sort processes by cpu or memory')
    parser.add_argument('--no-clear', action='store_true', help='Do not clear the screen each update')
    parser.add_argument('--compact', action='store_true', help='Compact output formatting')
    
    args = parser.parse_args()
    
    monitor = MacOSPerformanceMonitor()
    monitor.enable_temps = bool(args.temps)
    
    try:
        if args.continuous:
            end_time = time.time() + args.duration if args.duration else None
            while True:
                if args.json:
                    payload = monitor.get_json_report(
                        include_processes=not args.no_processes,
                        top_n=args.top,
                        sort_by=args.sort_by,
                        include_battery=not args.no_battery,
                    )
                    if args.ndjson:
                        line = json.dumps(payload)
                        if args.out:
                            with open(args.out, 'a') as f:
                                f.write(line + '\n')
                        else:
                            print(line)
                    else:
                        text = json.dumps(payload, indent=2)
                        if args.out:
                            with open(args.out, 'a') as f:
                                f.write(text + '\n')
                        else:
                            print(text)
                else:
                    if not args.no_clear:
                        monitor.console.clear()  # Clear screen using Rich
                    monitor.print_performance_report(
                        show_processes=not args.no_processes,
                        top_n=args.top,
                        sort_by=args.sort_by,
                        show_disk_io=not args.no_disk_io,
                        show_battery=not args.no_battery,
                        compact=args.compact,
                    )
                time.sleep(args.interval)
                if end_time and time.time() >= end_time:
                    break
        else:
            if args.json:
                payload = monitor.get_json_report(
                    include_processes=not args.no_processes,
                    top_n=args.top,
                    sort_by=args.sort_by,
                    include_battery=not args.no_battery,
                )
                if args.ndjson:
                    line = json.dumps(payload)
                    if args.out:
                        with open(args.out, 'w') as f:
                            f.write(line + '\n')
                    else:
                        print(line)
                else:
                    text = json.dumps(payload, indent=2)
                    if args.out:
                        with open(args.out, 'w') as f:
                            f.write(text + '\n')
                    else:
                        print(text)
            else:
                monitor.print_performance_report(
                    show_processes=not args.no_processes,
                    top_n=args.top,
                    sort_by=args.sort_by,
                    show_disk_io=not args.no_disk_io,
                    show_battery=not args.no_battery,
                    compact=args.compact,
                )
    except KeyboardInterrupt:
        print("\n\nMonitoring stopped.")


if __name__ == "__main__":
    main()
