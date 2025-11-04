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
from collections import defaultdict
from typing import Any, Dict, List, Optional


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
        """Print a formatted performance report"""
        print("=" * 70)
        print(f"macOS System Performance Report - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 70)
        
        # System Uptime
        uptime = self.get_system_uptime()
        print(f"\n📅 SYSTEM UPTIME")
        print(f"   Boot Time: {uptime['boot_time']}")
        print(f"   Uptime: {uptime['uptime_days']}d {uptime['uptime_hours']}h {uptime['uptime_minutes']}m")
        
        # CPU Information
        cpu = self.get_cpu_info()
        print(f"\n🖥️  CPU USAGE")
        print(f"   Overall: {cpu['overall_usage']}%")
        print(f"   Cores: {cpu['core_count']} physical, {cpu['thread_count']} logical")
        if cpu['frequency_mhz']:
            if cpu['max_frequency_mhz']:
                print(f"   Frequency: {cpu['frequency_mhz']:.0f} MHz (Max: {cpu['max_frequency_mhz']:.0f} MHz)")
            else:
                print(f"   Frequency: {cpu['frequency_mhz']:.0f} MHz")
        
        # Memory Information
        mem = self.get_memory_info()
        print(f"\n💾 MEMORY USAGE")
        print(f"   Used: {mem['used_gb']} GiB / {mem['total_gb']} GiB ({mem['percent']}%)")
        print(f"   Available: {mem['available_gb']} GiB")
        if mem['swap_used_gb'] > 0:
            print(f"   Swap: {mem['swap_used_gb']} GiB / {mem['swap_total_gb']} GiB ({mem['swap_percent']}%)")
        
        # Disk Information
        disk = self.get_disk_info()
        print(f"\n💿 DISK USAGE")
        for partition in disk['partitions']:
            print(f"   {partition['mountpoint']}: {partition['used_gib']} GiB / {partition['total_gib']} GiB ({partition['percent']}%)")
        
        if show_disk_io and disk['io_stats']:
            print(f"   I/O: {disk['io_stats']['read_mib']} MiB read, {disk['io_stats']['write_mib']} MiB written")
            print(f"        Rates: {disk['io_stats']['read_rate_mib_s']} MiB/s read, {disk['io_stats']['write_rate_mib_s']} MiB/s write")
        
        # Network Information
        net = self.get_network_info()
        print(f"\n🌐 NETWORK")
        print(f"   Sent: {net['bytes_sent_mib']} MiB ({net['send_rate_mib_s']} MiB/s)")
        print(f"   Received: {net['bytes_recv_mib']} MiB ({net['recv_rate_mib_s']} MiB/s)")
        
        # Battery Information
        if show_battery:
            battery = self.get_battery_info()
            if battery:
                print(f"\n🔋 BATTERY")
                status = "Charging" if battery['plugged_in'] else "Discharging"
                print(f"   Level: {battery['percent']}% ({status})")
                if battery['time_left_minutes']:
                    print(f"   Time Remaining: {battery['time_left_minutes']} minutes")
        
        # Temperature Information
        temp = self.get_temperature_info()
        if temp and 'cpu_temp_c' in temp:
            print(f"\n🌡️  TEMPERATURE")
            print(f"   CPU: {temp['cpu_temp_c']}°C")
        
        # Top Processes
        if show_processes:
            title_sort = 'CPU' if sort_by == 'cpu' else 'MEM'
            print(f"\n🔝 TOP {top_n} PROCESSES (by {title_sort})")
            top_list = self.get_top_processes(num=top_n, sort_by=sort_by)
            if not compact:
                print(f"   {'PID':<8} {'CPU%':<8} {'MEM%':<8} {'Name':<30} {'User':<15}")
                print(f"   {'-'*75}")
            for proc in top_list:
                line = f"   {proc['pid']:<8} {proc['cpu_percent']:<8.1f} {proc['memory_percent']:<8.1f} {proc['name'][:30]:<30} {proc['username'][:15]:<15}"
                print(line)
        
        print("\n" + "=" * 70)
    
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
                        print("\033[2J\033[H")  # Clear screen
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
