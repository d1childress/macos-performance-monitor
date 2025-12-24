#!/usr/bin/env python3
"""
macOS Performance Monitor - Advanced TUI Version
A user-friendly, feature-rich TUI with native macOS Liquid Glass styling.
Supports both light mode and dark mode.
"""

import psutil
from datetime import datetime
from collections import deque
from typing import Dict, Any, List

from textual.app import App, ComposeResult
from textual.containers import Container, Horizontal, Vertical, ScrollableContainer, Grid
from textual.widgets import (
    Header, Footer, Static, DataTable, Label, Button,
    TabbedContent, TabPane, Switch, Select, Input, ProgressBar, Rule
)
from textual.reactive import reactive
from textual.screen import Screen, ModalScreen
from textual.theme import Theme
from rich.panel import Panel
from rich.text import Text
from rich.table import Table
from rich.style import Style


class SettingsScreen(ModalScreen):
    """Modal screen for settings with Liquid Glass styling"""

    def compose(self) -> ComposeResult:
        with Vertical(id="settings-dialog"):
            yield Label("Settings", id="settings-title")
            yield Rule(style="dim")

            with Horizontal(classes="settings-row"):
                yield Label("Update Interval (seconds):", classes="settings-label")
                yield Input(value="1.0", id="interval-input", classes="settings-input")

            with Horizontal(classes="settings-row"):
                yield Label("Number of Processes:", classes="settings-label")
                yield Input(value="10", id="processes-input", classes="settings-input")

            with Horizontal(classes="settings-row"):
                yield Label("Temperature Monitoring:", classes="settings-label")
                yield Switch(value=False, id="temp-switch")

            with Horizontal(classes="settings-row"):
                yield Label("Theme Mode:", classes="settings-label")
                yield Button("Toggle Light/Dark", id="theme-toggle-btn", variant="default")

            yield Rule(style="dim")
            with Horizontal(id="settings-buttons"):
                yield Button("Save", variant="success", id="save-btn")
                yield Button("Cancel", variant="error", id="cancel-btn")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "save-btn":
            interval = self.query_one("#interval-input", Input).value
            num_procs = self.query_one("#processes-input", Input).value
            enable_temps = self.query_one("#temp-switch", Switch).value

            self.app.notify(f"Settings saved: interval={interval}s, procs={num_procs}")
            self.dismiss({"interval": interval, "processes": num_procs, "temps": enable_temps})
        elif event.button.id == "theme-toggle-btn":
            self.app.dark = not self.app.dark
            mode = "Dark" if self.app.dark else "Light"
            self.app.notify(f"Switched to {mode} mode")
        else:
            self.dismiss(None)


class CPUDetailWidget(Static):
    """Detailed CPU metrics widget"""

    def __init__(self, monitor, **kwargs):
        super().__init__(**kwargs)
        self.monitor = monitor
        self.history = deque(maxlen=50)  # More history for details

    def on_mount(self) -> None:
        self.update_timer = self.set_interval(1.0, self.update_cpu)

    def update_cpu(self) -> None:
        cpu_info = self.monitor.get_cpu_info()
        self.history.append(cpu_info['overall_usage'])
        self.refresh()

    def render(self) -> Panel:
        cpu_info = self.monitor.get_cpu_info()
        sparkline = self._create_sparkline(list(self.history))

        lines = [
            f"Overall CPU Usage: {cpu_info['overall_usage']:.1f}%",
            f"Sparkline (last 50s): {sparkline}",
            f"",
            f"Physical Cores: {cpu_info['core_count']}",
            f"Logical Cores: {cpu_info['thread_count']}",
        ]

        if cpu_info.get('frequency_mhz'):
            lines.append(f"Current Frequency: {cpu_info['frequency_mhz']:.0f} MHz")
            if cpu_info.get('max_frequency_mhz'):
                lines.append(f"Max Frequency: {cpu_info['max_frequency_mhz']:.0f} MHz")

        lines.append("\nPer-Core Usage:")
        if cpu_info.get('per_core_usage'):
            for i, core_pct in enumerate(cpu_info['per_core_usage']):
                bar = self._create_progress_bar(core_pct, width=40)
                lines.append(f"  Core {i:2d}: {bar} {core_pct:5.1f}%")

        # Add statistics
        if self.history:
            avg = sum(self.history) / len(self.history)
            max_val = max(self.history)
            min_val = min(self.history)
            lines.append(f"\nStatistics (last {len(self.history)}s):")
            lines.append(f"  Average: {avg:.1f}%")
            lines.append(f"  Maximum: {max_val:.1f}%")
            lines.append(f"  Minimum: {min_val:.1f}%")

        content = "\n".join(lines)
        color = self._get_status_color(cpu_info['overall_usage'])

        return Panel(
            content,
            title="[bold]CPU Details[/bold]",
            border_style=color,
            padding=(1, 2)
        )

    def _create_sparkline(self, data: List[float]) -> str:
        if not data:
            return ""
        chars = "▁▂▃▄▅▆▇█"
        max_val = max(data) if max(data) > 0 else 1
        normalized = [int(val / max_val * (len(chars) - 1)) for val in data]
        return ''.join(chars[i] for i in normalized)

    def _create_progress_bar(self, percent: float, width: int = 20) -> str:
        filled = int(width * percent / 100)
        return "█" * filled + "░" * (width - filled)

    def _get_status_color(self, percent: float) -> str:
        if percent >= 90:
            return "red"
        elif percent >= 70:
            return "yellow"
        elif percent >= 50:
            return "blue"
        return "green"


class MemoryDetailWidget(Static):
    """Detailed memory metrics widget"""

    def __init__(self, monitor, **kwargs):
        super().__init__(**kwargs)
        self.monitor = monitor

    def on_mount(self) -> None:
        self.update_timer = self.set_interval(2.0, self.refresh)

    def render(self) -> Panel:
        mem_info = self.monitor.get_memory_info()

        lines = []

        # RAM Section
        lines.append("[bold]RAM[/bold]")
        lines.append(f"  Total:     {mem_info['total_gb']:.2f} GB")
        lines.append(f"  Used:      {mem_info['used_gb']:.2f} GB")
        lines.append(f"  Available: {mem_info['available_gb']:.2f} GB")
        lines.append(f"  Percent:   {mem_info['percent']:.1f}%")
        bar = self._create_progress_bar(mem_info['percent'], width=40)
        lines.append(f"  {bar}")

        # Swap Section
        if mem_info.get('swap_total_gb', 0) > 0:
            lines.append("")
            lines.append("[bold]Swap[/bold]")
            lines.append(f"  Total:   {mem_info['swap_total_gb']:.2f} GB")
            lines.append(f"  Used:    {mem_info['swap_used_gb']:.2f} GB")
            lines.append(f"  Percent: {mem_info['swap_percent']:.1f}%")
            swap_bar = self._create_progress_bar(mem_info['swap_percent'], width=40)
            lines.append(f"  {swap_bar}")

        content = "\n".join(lines)
        color = self._get_status_color(mem_info['percent'])

        return Panel(
            content,
            title="[bold]Memory Details[/bold]",
            border_style=color,
            padding=(1, 2)
        )

    def _format_bytes(self, bytes_val: int) -> str:
        """Format bytes to human-readable format"""
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if bytes_val < 1024.0:
                return f"{bytes_val:.2f} {unit}"
            bytes_val /= 1024.0
        return f"{bytes_val:.2f} PB"

    def _create_progress_bar(self, percent: float, width: int = 20) -> str:
        filled = int(width * percent / 100)
        return "█" * filled + "░" * (width - filled)

    def _get_status_color(self, percent: float) -> str:
        if percent >= 90:
            return "red"
        elif percent >= 70:
            return "yellow"
        elif percent >= 50:
            return "blue"
        return "green"


class NetworkDetailWidget(Static):
    """Detailed network metrics widget"""

    def __init__(self, monitor, **kwargs):
        super().__init__(**kwargs)
        self.monitor = monitor
        self.history_up = deque(maxlen=60)
        self.history_down = deque(maxlen=60)

    def on_mount(self) -> None:
        self.update_timer = self.set_interval(1.0, self.update_network)

    def update_network(self) -> None:
        net_info = self.monitor.get_network_info()
        self.history_up.append(net_info.get('send_rate_mib_s', 0) * 1024 * 1024)  # Convert to bytes/s
        self.history_down.append(net_info.get('recv_rate_mib_s', 0) * 1024 * 1024)
        self.refresh()

    def render(self) -> Panel:
        net_info = self.monitor.get_network_info()

        lines = []
        lines.append("[bold]Current Rates[/bold]")
        lines.append(f"  Upload:   {net_info.get('send_rate_mib_s', 0):.2f} MiB/s")
        lines.append(f"  Download: {net_info.get('recv_rate_mib_s', 0):.2f} MiB/s")

        lines.append("")
        lines.append("[bold]Total Transfer[/bold]")
        lines.append(f"  Sent:     {net_info.get('bytes_sent_mib', 0):.2f} MiB")
        lines.append(f"  Received: {net_info.get('bytes_recv_mib', 0):.2f} MiB")

        lines.append("")
        lines.append("[bold]Sparklines (last 60s)[/bold]")
        sparkline_up = self._create_sparkline(list(self.history_up))
        sparkline_down = self._create_sparkline(list(self.history_down))
        lines.append(f"  ↑ {sparkline_up}")
        lines.append(f"  ↓ {sparkline_down}")

        # Add statistics
        if self.history_down:
            avg_down = sum(self.history_down) / len(self.history_down)
            max_down = max(self.history_down)
            avg_up = sum(self.history_up) / len(self.history_up)
            max_up = max(self.history_up)

            lines.append("")
            lines.append("[bold]Statistics (last 60s)[/bold]")
            lines.append(f"  Avg Download: {self._format_bytes(avg_down)}/s")
            lines.append(f"  Max Download: {self._format_bytes(max_down)}/s")
            lines.append(f"  Avg Upload:   {self._format_bytes(avg_up)}/s")
            lines.append(f"  Max Upload:   {self._format_bytes(max_up)}/s")

        content = "\n".join(lines)

        return Panel(
            content,
            title="[bold]Network Details[/bold]",
            border_style="cyan",
            padding=(1, 2)
        )

    def _format_bytes(self, bytes_val: int) -> str:
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if bytes_val < 1024.0:
                return f"{bytes_val:.2f} {unit}"
            bytes_val /= 1024.0
        return f"{bytes_val:.2f} PB"

    def _create_sparkline(self, data: List[float]) -> str:
        if not data or max(data) == 0:
            return "▁" * min(len(data), 60)
        chars = "▁▂▃▄▅▆▇█"
        max_val = max(data)
        normalized = [int(val / max_val * (len(chars) - 1)) for val in data]
        return ''.join(chars[i] for i in normalized)


class ProcessTableDetailWidget(Static):
    """Enhanced process table with more details"""

    def __init__(self, monitor, **kwargs):
        super().__init__(**kwargs)
        self.monitor = monitor
        self.sort_by = 'cpu'
        self.num_processes = 20

    def compose(self) -> ComposeResult:
        with Vertical():
            with Horizontal():
                yield Button("Sort: CPU", id="sort-cpu-btn", variant="primary")
                yield Button("Sort: Memory", id="sort-mem-btn")
                yield Button("Top 10", id="top-10-btn")
                yield Button("Top 20", id="top-20-btn")
                yield Button("Top 50", id="top-50-btn")
            yield DataTable()

    def on_mount(self) -> None:
        table = self.query_one(DataTable)
        table.add_columns("PID", "Name", "CPU %", "Memory %", "User")
        table.cursor_type = "row"
        self.update_timer = self.set_interval(2.0, self.update_processes)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "sort-cpu-btn":
            self.sort_by = 'cpu'
            self.query_one("#sort-cpu-btn", Button).variant = "primary"
            self.query_one("#sort-mem-btn", Button).variant = "default"
        elif event.button.id == "sort-mem-btn":
            self.sort_by = 'memory'
            self.query_one("#sort-cpu-btn", Button).variant = "default"
            self.query_one("#sort-mem-btn", Button).variant = "primary"
        elif event.button.id == "top-10-btn":
            self.num_processes = 10
        elif event.button.id == "top-20-btn":
            self.num_processes = 20
        elif event.button.id == "top-50-btn":
            self.num_processes = 50

        self.update_processes()

    def update_processes(self) -> None:
        table = self.query_one(DataTable)
        table.clear()

        processes = self.monitor.get_top_processes(
            num=self.num_processes,
            sort_by=self.sort_by
        )

        for proc in processes:
            table.add_row(
                str(proc['pid']),
                proc['name'][:30],
                f"{proc['cpu_percent']:.1f}",
                f"{proc['memory_percent']:.1f}",
                proc.get('username', 'N/A')[:20]
            )


class OverviewWidget(Static):
    """Overview widget showing all key metrics at a glance"""

    def __init__(self, monitor, **kwargs):
        super().__init__(**kwargs)
        self.monitor = monitor

    def on_mount(self) -> None:
        self.update_timer = self.set_interval(1.0, self.refresh)

    def render(self) -> Panel:
        cpu_info = self.monitor.get_cpu_info()
        mem_info = self.monitor.get_memory_info()
        net_info = self.monitor.get_network_info()

        # Create a compact overview
        lines = []

        # System info header
        lines.append("[bold cyan]macOS Performance Monitor[/bold cyan]")
        lines.append(f"[dim]{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}[/dim]")
        lines.append("")

        # CPU Section
        cpu_pct = cpu_info['overall_usage']
        cpu_bar = self._create_gradient_bar(cpu_pct, 30)
        cpu_color = self._get_status_color(cpu_pct)
        lines.append(f"[bold]CPU[/bold]")
        lines.append(f"  {cpu_bar} [{cpu_color}]{cpu_pct:.1f}%[/{cpu_color}]")
        lines.append(f"  [dim]{cpu_info['core_count']} cores / {cpu_info['thread_count']} threads[/dim]")
        lines.append("")

        # Memory Section
        mem_pct = mem_info['percent']
        mem_bar = self._create_gradient_bar(mem_pct, 30)
        mem_color = self._get_status_color(mem_pct)
        lines.append(f"[bold]Memory[/bold]")
        lines.append(f"  {mem_bar} [{mem_color}]{mem_pct:.1f}%[/{mem_color}]")
        lines.append(f"  [dim]{mem_info['used_gb']:.1f} GB / {mem_info['total_gb']:.1f} GB[/dim]")
        lines.append("")

        # Network Section
        lines.append(f"[bold]Network[/bold]")
        lines.append(f"  [green]↑[/green] {net_info.get('send_rate_mib_s', 0):.2f} MiB/s")
        lines.append(f"  [blue]↓[/blue] {net_info.get('recv_rate_mib_s', 0):.2f} MiB/s")
        lines.append("")

        # Quick Tips
        lines.append("[dim]Press [bold]d[/bold] for dark/light mode | [bold]s[/bold] for settings | [bold]q[/bold] to quit[/dim]")

        content = "\n".join(lines)

        return Panel(
            content,
            title="[bold]System Overview[/bold]",
            border_style="bright_cyan",
            padding=(1, 2),
            subtitle="[dim]Liquid Glass[/dim]"
        )

    def _create_gradient_bar(self, percent: float, width: int = 20) -> str:
        """Create a gradient progress bar with macOS-style coloring"""
        filled = int(width * percent / 100)
        empty = width - filled

        if percent >= 90:
            filled_char = "[red]█[/red]"
        elif percent >= 70:
            filled_char = "[yellow]█[/yellow]"
        elif percent >= 50:
            filled_char = "[blue]█[/blue]"
        else:
            filled_char = "[green]█[/green]"

        return filled_char * filled + "[dim]░[/dim]" * empty

    def _get_status_color(self, percent: float) -> str:
        if percent >= 90:
            return "red"
        elif percent >= 70:
            return "yellow"
        elif percent >= 50:
            return "blue"
        return "green"


class MacOSMonitorAdvancedTUI(App):
    """
    Advanced TUI with native macOS Liquid Glass styling.
    Features light mode and dark mode support.
    """

    TITLE = "macOS Performance Monitor"
    SUB_TITLE = "Liquid Glass Edition"

    CSS = """
    /* ============================================
       macOS Liquid Glass Theme
       Inspired by Cursor / ChatGPT / MarkEdit
       ============================================ */

    Screen {
        background: $background;
        color: $text;
    }

    #workspace {
        padding: 1 2;
        background: $surface;
        border: tall $primary 20%;
        layer: outline;
    }

    /* Liquid Glass effect - semi-transparent panels */
    Static.glass-card {
        background: $surface 80%;
        border: round $primary 35%;
        padding: 1 1;
    }

    /* Header styling - macOS window bar style */
    Header {
        background: $primary-background;
        color: $text;
        dock: top;
        text-style: bold;
    }

    Header.-tall {
        background: $primary-background;
    }

    /* Footer styling */
    Footer {
        background: $primary-background;
        color: $text-muted;
        text-style: bold;
    }

    /* Tabbed content - main navigation */
    TabbedContent {
        height: 100%;
        background: transparent;
    }

    Tabs {
        background: $surface;
        dock: top;
        border: round $primary 30%;
        margin: 0 1 1 1;
    }

    Tab {
        background: transparent;
        color: $text-muted;
        padding: 0 3;
        height: 3;
        border: tall transparent;
    }

    Tab:hover {
        background: $primary 15%;
        color: $text;
    }

    Tab.-active {
        background: $primary 25%;
        color: $primary;
        text-style: bold;
        border: tall $primary 50%;
    }

    TabPane {
        padding: 1 2;
        background: transparent;
    }

    /* Data tables - process list styling */
    DataTable {
        background: $surface;
        height: auto;
        border: round $primary 50%;
        padding: 0 1 1 1;
    }

    DataTable > .datatable--header {
        background: $primary 20%;
        color: $text;
        text-style: bold;
    }

    DataTable > .datatable--cursor {
        background: $primary 40%;
        color: $text;
    }

    /* Settings modal - Liquid Glass popup */
    #settings-dialog {
        width: 68;
        height: auto;
        background: $surface;
        border: thick $primary 50%;
        padding: 1 2;
        layer: overlay;
    }

    #settings-title {
        text-align: center;
        text-style: bold;
        color: $primary;
        margin: 1 0;
        width: 100%;
    }

    .settings-row {
        height: 3;
        margin: 1 0;
        align: left middle;
    }

    .settings-label {
        width: 32;
        color: $text;
    }

    .settings-input {
        width: 22;
        background: $background;
        border: tall $primary 30%;
    }

    #settings-buttons {
        margin-top: 1;
        align: center middle;
    }

    /* Buttons - macOS rounded style */
    Button {
        margin: 0 1;
        min-width: 12;
        border: tall $primary 50%;
        text-style: bold;
    }

    Button:hover {
        background: $primary 30%;
    }

    Button.-primary {
        background: $primary;
        color: $background;
    }

    Button.-success {
        background: $success;
        color: $background;
    }

    Button.-error {
        background: $error;
        color: $background;
    }

    /* Switch - iOS style toggle */
    Switch {
        background: $surface;
        border: tall $primary 30%;
    }

    Switch:focus {
        border: tall $primary;
    }

    Switch.-on {
        background: $success;
    }

    Switch.-on > .switch--slider {
        background: $background;
    }

    /* Input fields */
    Input {
        background: $background;
        border: tall $primary 30%;
    }

    Input:focus {
        border: tall $primary;
    }

    /* Rules / Dividers */
    Rule {
        color: $primary 30%;
        margin: 1 0;
    }

    /* Process table buttons */
    ProcessTableDetailWidget Button {
        min-width: 10;
        height: 3;
    }

    /* Panels - Liquid Glass effect */
    Static Panel {
        border: round $primary 30%;
    }
    """

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("s", "show_settings", "Settings"),
        ("r", "refresh", "Refresh"),
        ("d", "toggle_dark", "Light/Dark"),
        ("1", "tab_overview", "Overview"),
        ("2", "tab_cpu", "CPU"),
        ("3", "tab_memory", "Memory"),
        ("4", "tab_network", "Network"),
        ("5", "tab_processes", "Processes"),
    ]

    def __init__(self):
        super().__init__()
        from macos_performance_monitor import MacOSPerformanceMonitor
        self.monitor = MacOSPerformanceMonitor()

    def compose(self) -> ComposeResult:
        """Create child widgets with tabs"""
        yield Header()

        with TabbedContent(id="main-tabs"):
            with TabPane("Overview", id="tab-overview"):
                yield OverviewWidget(self.monitor)

            with TabPane("CPU", id="tab-cpu"):
                yield CPUDetailWidget(self.monitor)

            with TabPane("Memory", id="tab-memory"):
                yield MemoryDetailWidget(self.monitor)

            with TabPane("Network", id="tab-network"):
                yield NetworkDetailWidget(self.monitor)

            with TabPane("Processes", id="tab-processes"):
                yield ProcessTableDetailWidget(self.monitor)

        yield Footer()

    def action_show_settings(self) -> None:
        """Show settings modal"""
        self.push_screen(SettingsScreen(), self.handle_settings)

    def handle_settings(self, settings: dict) -> None:
        """Handle settings changes"""
        if settings:
            self.notify(f"Settings updated: {settings}")

    def action_refresh(self) -> None:
        """Force refresh all widgets"""
        self.notify("Refreshing all data...")
        for widget in self.query(Static):
            if hasattr(widget, 'refresh'):
                widget.refresh()

    def action_toggle_dark(self) -> None:
        """Toggle between light and dark mode"""
        self.dark = not self.dark
        mode = "Dark" if self.dark else "Light"
        self.notify(f"{mode} mode enabled")

    def action_tab_overview(self) -> None:
        """Switch to Overview tab"""
        self.query_one("#main-tabs", TabbedContent).active = "tab-overview"

    def action_tab_cpu(self) -> None:
        """Switch to CPU tab"""
        self.query_one("#main-tabs", TabbedContent).active = "tab-cpu"

    def action_tab_memory(self) -> None:
        """Switch to Memory tab"""
        self.query_one("#main-tabs", TabbedContent).active = "tab-memory"

    def action_tab_network(self) -> None:
        """Switch to Network tab"""
        self.query_one("#main-tabs", TabbedContent).active = "tab-network"

    def action_tab_processes(self) -> None:
        """Switch to Processes tab"""
        self.query_one("#main-tabs", TabbedContent).active = "tab-processes"


if __name__ == "__main__":
    app = MacOSMonitorAdvancedTUI()
    app.run()
