"""PC を操作するツールを Claude Code に渡す MCP サーバー。

アシスタント（claude_agent.py）が claude を起動するときに、--mcp-config で読み込ませる。
run_command だけは、実行前にアシスタントの画面で確認ダイアログを出す。
"""

from __future__ import annotations

import json
import os
import platform
import shutil
import socket
import subprocess
from pathlib import Path

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio  # noqa: E402
from mcp.server.mcpserver import MCPServer  # noqa: E402

MAX_OUTPUT_CHARS = 10_000
COMMAND_TIMEOUT_SECONDS = 120

mcp = MCPServer("myos")


@mcp.tool()
def list_apps() -> str:
    """List installed desktop applications as `id: name` lines."""
    lines = []
    for info in Gio.AppInfo.get_all():
        if not info.should_show():
            continue
        app_id = (info.get_id() or "").removesuffix(".desktop")
        lines.append(f"{app_id}: {info.get_display_name()}")
    return "\n".join(sorted(lines)) or "(no apps found)"


@mcp.tool()
def open_app(app_id: str) -> str:
    """Launch an installed application by the id shown by list_apps (e.g. org.mozilla.firefox)."""
    app_id = app_id.removesuffix(".desktop")
    info = Gio.DesktopAppInfo.new(app_id + ".desktop")
    if info is None:
        raise ValueError(f"app `{app_id}` is not installed; call list_apps to see valid ids")
    info.launch([], None)
    return f"launched {info.get_display_name()}"


@mcp.tool()
def set_appearance(mode: str) -> str:
    """Switch the desktop between light and dark mode. `mode` is "light" or "dark"."""
    if mode not in ("light", "dark"):
        raise ValueError("`mode` must be light or dark")
    settings = Gio.Settings.new("org.gnome.desktop.interface")
    settings.set_string("color-scheme", "prefer-dark" if mode == "dark" else "default")
    Gio.Settings.sync()
    return f"appearance set to {mode}"


def _read_key_values(path: str, sep: str) -> dict[str, str]:
    values = {}
    try:
        for line in Path(path).read_text(errors="replace").splitlines():
            key, found, value = line.partition(sep)
            if found:
                values.setdefault(key.strip(), value.strip().strip('"'))
    except OSError:
        pass
    return values


@mcp.tool()
def system_info() -> str:
    """Get the OS version, kernel, CPU, GPU, memory and disk usage."""
    os_release = _read_key_values("/etc/os-release", "=")
    cpu = _read_key_values("/proc/cpuinfo", ":").get("model name", "unknown")
    meminfo = _read_key_values("/proc/meminfo", ":")

    def gib(kib_text: str) -> str:
        try:
            return f"{int(kib_text.split()[0]) / 1024 / 1024:.1f} GiB"
        except (ValueError, IndexError):
            return "unknown"

    gpus = "unknown"
    try:
        lspci = subprocess.run(["lspci"], capture_output=True, text=True, timeout=10).stdout
        gpus = "; ".join(
            line.split(": ", 1)[-1]
            for line in lspci.splitlines()
            if "VGA" in line or "3D controller" in line or "Display controller" in line
        ) or "unknown"
    except (OSError, subprocess.SubprocessError):
        pass

    lines = [
        f"OS: {os_release.get('PRETTY_NAME', 'unknown')}",
        f"Kernel: {platform.release()}",
        f"CPU: {cpu}",
        f"GPU: {gpus}",
        f"Memory: {gib(meminfo.get('MemAvailable', ''))} available of "
        f"{gib(meminfo.get('MemTotal', ''))}",
    ]
    for label, path in (("Disk /", "/"), ("Disk home", str(Path.home()))):
        usage = shutil.disk_usage(path)
        lines.append(
            f"{label}: {usage.free / 1024**3:.0f} GiB free of {usage.total / 1024**3:.0f} GiB"
        )
    return "\n".join(lines)


def _ask_user(command: str, reason: str) -> bool:
    """アシスタントの画面に確認ダイアログを出してもらい、答えを待つ。"""
    socket_path = os.environ.get("MYOS_CONFIRM_SOCKET")
    if not socket_path:
        return False
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.connect(socket_path)
        connection.sendall((json.dumps({"command": command, "reason": reason}) + "\n").encode())
        reply = connection.makefile(encoding="utf-8").readline()
    return bool(json.loads(reply or "{}").get("approved"))


@mcp.tool()
def run_command(command: str, reason: str) -> str:
    """Run a bash command as the current user (not root) after the user approves it in a
    confirmation dialog. `reason` is one sentence in the user's language shown in that dialog.
    Returns the exit code, stdout and stderr (truncated)."""
    if not _ask_user(command, reason):
        return "The user declined to run this command."
    try:
        result = subprocess.run(
            ["bash", "-lc", command],
            capture_output=True,
            text=True,
            timeout=COMMAND_TIMEOUT_SECONDS,
            cwd=Path.home(),
        )
    except subprocess.TimeoutExpired:
        raise TimeoutError(f"command timed out after {COMMAND_TIMEOUT_SECONDS} seconds")
    output = (
        f"exit code: {result.returncode}\n"
        f"--- stdout ---\n{result.stdout}\n--- stderr ---\n{result.stderr}"
    )
    if len(output) > MAX_OUTPUT_CHARS:
        output = output[:MAX_OUTPUT_CHARS] + f"\n...（{len(output) - MAX_OUTPUT_CHARS} 文字省略）"
    return output


if __name__ == "__main__":
    mcp.run()
