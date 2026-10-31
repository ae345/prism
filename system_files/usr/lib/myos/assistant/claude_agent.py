"""Claude Code（サブスクリプションでログインしたもの）を裏で動かすアシスタント本体。

`claude -p` を会話の1ターンごとに起動し、`--resume` で会話を続ける。
PC を操作するツールは os_tools_server.py（MCP サーバー）が提供する。
GTK には依存しない。UI との受け渡しは Callbacks を通して行う。
"""

from __future__ import annotations

import atexit
import json
import os
import shutil
import socket
import subprocess
import sys
import threading
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

TOOL_SERVER = Path(__file__).with_name("os_tools_server.py")
OS_TOOLS = ["list_apps", "open_app", "set_appearance", "system_info", "run_command"]
# Read は Claude ボールが撮ったスクリーンショット（~/.cache/myos）だけ読めるようにする
ALLOWED_TOOLS = ["WebSearch", "WebFetch", "Read(~/.cache/myos/**)"] + [
    f"mcp__myos__{name}" for name in OS_TOOLS
]

SYSTEM_PROMPT = """\
You are the built-in assistant of Prism, a Fedora-based Linux desktop (GNOME, based on Bazzite) \
used for games and everyday work. Reply in the user's language (usually Japanese). \
Begin your visible answer immediately and keep answers short. \
Use plain text; Markdown is limited to **bold** and `inline code`.

You can act on this computer through the myos tools. Prefer the dedicated tools (list_apps, \
open_app, set_appearance, system_info) over run_command. run_command shows the user a \
confirmation dialog before anything runs; say in one sentence what the command does in its \
`reason`. The system image is read-only: install apps with `flatpak install --user flathub <id>`, \
never dnf. Windows games run through Steam with Proton. You can search the web for current \
information. When the user mentions a screenshot in ~/.cache/myos, look at it with the Read tool. \
Never run commands that delete user data unless the user explicitly asked for it."""

LOGIN_ERROR_HINTS = ("/login", "not logged in", "invalid api key", "authentication", "oauth")


@dataclass
class Callbacks:
    on_text: Callable[[str], None]
    """返答の文字列が届くたびに呼ばれる（差分）。"""
    on_tool: Callable[[str, dict], None]
    """ツールを実行するときに呼ばれる。"""
    confirm_command: Callable[[str, str], bool]
    """コマンドを実行してよいかユーザーに聞く。答えが出るまで戻らない。"""


class AssistantError(Exception):
    pass


class NotLoggedInError(AssistantError):
    pass


def claude_path() -> str | None:
    found = shutil.which("claude")
    if found:
        return found
    local = Path.home() / ".local" / "bin" / "claude"
    return str(local) if local.exists() else None


def login_status() -> str:
    """"missing"（未インストール）/ "logged_out" / "ok" のどれかを返す。"""
    claude = claude_path()
    if claude is None:
        return "missing"
    try:
        result = subprocess.run(
            [claude, "auth", "status", "--json"], capture_output=True, text=True, timeout=30
        )
        status = json.loads(result.stdout)
    except (OSError, subprocess.SubprocessError, ValueError):
        return "logged_out"
    return "ok" if status.get("loggedIn") else "logged_out"


class Assistant:
    def __init__(self):
        self.session_id: str | None = None
        self._callbacks: Callbacks | None = None
        runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp")
        self._socket_path = runtime_dir / f"myos-assistant-{os.getpid()}.sock"
        threading.Thread(target=self._serve_confirmations, daemon=True).start()

    def reset(self) -> None:
        self.session_id = None

    def send(self, text: str, cb: Callbacks) -> None:
        """1ターン分の会話を行う。UI スレッドをふさがないよう、別スレッドから呼ぶこと。"""
        claude = claude_path()
        if claude is None:
            raise NotLoggedInError("Claude Code is not installed")

        self._callbacks = cb
        # Claude Code は作業フォルダの中なら聞かずに読めるので、ホームではなく
        # スクリーンショット置き場を作業フォルダにして、読める範囲をそこだけにする
        workdir = Path.home() / ".cache" / "myos"
        workdir.mkdir(parents=True, exist_ok=True)
        process = subprocess.Popen(
            self._command(claude),
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            cwd=workdir,
        )
        # 質問は標準入力で渡す（"-" で始まる文がオプション扱いされないように）
        process.stdin.write(text)
        process.stdin.close()
        # stderr があふれて止まらないよう、別スレッドで読み捨てておく
        stderr_lines: list[str] = []
        stderr_reader = threading.Thread(
            target=lambda: stderr_lines.extend(process.stderr), daemon=True
        )
        stderr_reader.start()

        result = self._read_stream(process.stdout, cb)
        process.wait()
        stderr_reader.join(timeout=5)

        if result is None or result.get("is_error"):
            detail = (result or {}).get("result") or "".join(stderr_lines[-20:]).strip()
            if any(hint in detail.lower() for hint in LOGIN_ERROR_HINTS):
                raise NotLoggedInError(detail)
            raise AssistantError(detail or f"claude exited with code {process.returncode}")

    def _command(self, claude: str) -> list[str]:
        mcp_config = {
            "mcpServers": {
                "myos": {
                    "command": sys.executable,
                    "args": [str(TOOL_SERVER)],
                    "env": {"MYOS_CONFIRM_SOCKET": str(self._socket_path)},
                }
            }
        }
        command = [
            claude,
            "-p",
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--system-prompt", SYSTEM_PROMPT,
            # Claude Code 自身のファイル編集やシェルは使わせず、確認つきの myos ツールに限る。
            # Read は ALLOWED_TOOLS で ~/.cache/myos だけに絞っている（それ以外は聞かずに断られる）
            "--tools", "WebSearch,WebFetch,Read",
            "--allowedTools", ",".join(ALLOWED_TOOLS),
            "--mcp-config", json.dumps(mcp_config),
            "--strict-mcp-config",
            # 許可していない操作は、聞かずに断る（裏で止まったままにならないように）
            "--permission-prompts", "none",
        ]
        model = os.environ.get("MYOS_ASSISTANT_MODEL")
        if model:
            command += ["--model", model]
        if self.session_id:
            command += ["--resume", self.session_id]
        return command

    def _read_stream(self, lines: Any, cb: Callbacks) -> dict | None:
        result = None
        wrote_text = False
        needs_break = False
        for line in lines:
            try:
                message = json.loads(line)
            except ValueError:
                continue
            kind = message.get("type")
            if message.get("parent_tool_use_id"):
                continue  # サブエージェント内部のやり取りは表示しない
            if kind == "system" and message.get("subtype") == "init":
                self.session_id = message.get("session_id") or self.session_id
            elif kind == "stream_event":
                event = message.get("event") or {}
                if event.get("type") == "message_start" and wrote_text:
                    needs_break = True  # ツールを挟んで次の返答が始まった
                delta = event.get("delta") or {}
                if event.get("type") == "content_block_delta" and delta.get("type") == "text_delta":
                    text = delta.get("text", "")
                    if needs_break and text:
                        text = "\n\n" + text
                        needs_break = False
                    wrote_text = wrote_text or bool(text)
                    cb.on_text(text)
            elif kind == "assistant":
                for block in (message.get("message") or {}).get("content") or []:
                    if block.get("type") == "tool_use":
                        name = block.get("name", "").removeprefix("mcp__myos__")
                        cb.on_tool(name, block.get("input") or {})
            elif kind == "result":
                result = message
                self.session_id = message.get("session_id") or self.session_id
        return result

    # --- コマンド実行の確認（MCP サーバー → この画面） ---

    def _serve_confirmations(self) -> None:
        self._socket_path.unlink(missing_ok=True)
        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(str(self._socket_path))
        os.chmod(self._socket_path, 0o600)
        server.listen()
        atexit.register(self._socket_path.unlink, missing_ok=True)
        while True:
            connection, _ = server.accept()
            with connection:
                try:
                    request = json.loads(connection.makefile(encoding="utf-8").readline())
                    callbacks = self._callbacks
                    approved = bool(
                        callbacks
                        and callbacks.confirm_command(str(request["command"]), str(request["reason"]))
                    )
                except (ValueError, KeyError, OSError):
                    approved = False
                connection.sendall((json.dumps({"approved": approved}) + "\n").encode())
