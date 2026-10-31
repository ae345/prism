"""Prism のアシスタント画面。Super + C で呼び出す Claude のチャット。

Claude の Pro / Max プラン（Claude Code にログインしたアカウント）で動く。
ウィンドウを閉じても会話は残り、次に呼び出したときに続きから話せる。
"""

from __future__ import annotations

import re
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gdk, Gio, GLib, Gtk, Pango  # noqa: E402

from claude_agent import (  # noqa: E402
    Assistant,
    AssistantError,
    Callbacks,
    NotLoggedInError,
    login_status,
)

APP_ID = "io.github.myos.Assistant"

TOOL_LABELS = {
    "list_apps": "アプリの一覧を確認しています…",
    "open_app": "アプリを開いています…",
    "set_appearance": "外観を切り替えています…",
    "system_info": "PCの情報を調べています…",
    "run_command": "コマンドを実行しています…",
    "WebSearch": "Webで検索しています…",
    "WebFetch": "Webページを読んでいます…",
}

SUGGESTIONS = [
    "ダークモードにして",
    "このPCのスペックを教えて",
    "Steamを開いて",
    "ディスクの空きはどれくらい？",
]

# Apple のメッセージアプリに近い見た目（青い吹き出し、角の丸い入力欄）
CSS = """
window.assistant { font-size: 14px; }
.bubble { padding: 9px 14px; border-radius: 20px; }
.bubble.user {
  background: #0a84ff; color: white; border-bottom-right-radius: 6px;
}
.bubble.assistant {
  background: alpha(#78787f, 0.16); border-bottom-left-radius: 6px;
}
.tool-status { font-size: 12px; opacity: 0.6; }
.composer {
  border-radius: 22px; padding: 4px 4px 4px 16px; min-height: 36px;
  background: var(--view-bg-color); box-shadow: 0 0 0 1px alpha(currentColor, 0.1);
}
.composer > entry {
  background: none; border: none; box-shadow: none; outline: none; min-height: 32px; padding: 0;
}
.send {
  min-width: 32px; min-height: 32px; padding: 0; border-radius: 999px;
  background: #0a84ff; color: white;
}
.send:disabled { background: alpha(#78787f, 0.3); }
.command-preview {
  padding: 10px 12px; border-radius: 10px; background: alpha(#78787f, 0.12);
  font-size: 12px;
}
"""


SOUND_DIR = "/usr/share/sounds/myos/stereo"
_playing: set[Gtk.MediaFile] = set()


def play_sound(name: str) -> None:
    """Prism の効果音を鳴らす。設定で効果音がオフなら鳴らさない。"""
    if not Gio.Settings.new("org.gnome.desktop.sound").get_boolean("event-sounds"):
        return
    media = Gtk.MediaFile.new_for_filename(f"{SOUND_DIR}/{name}.wav")
    _playing.add(media)  # 鳴り終わる前に片付けられないよう、参照を持っておく
    media.connect("notify::ended", lambda m, _pspec: _playing.discard(m))
    media.play()


def to_markup(text: str) -> str:
    """**太字** と `コード` だけを Pango のマークアップに変換する。"""
    markup = GLib.markup_escape_text(text)
    markup = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", markup)
    # タグをまたがないよう、< を含む範囲はコード扱いにしない
    return re.sub(r"`([^`<\n]+)`", r"<tt>\1</tt>", markup)


class MessageBubble(Gtk.Box):
    def __init__(self, role: str):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.set_halign(Gtk.Align.END if role == "user" else Gtk.Align.START)
        self.add_css_class("bubble")
        self.add_css_class(role)
        self.text = ""

        self.status = Gtk.Label(xalign=0, wrap=True, visible=False)
        self.status.add_css_class("tool-status")
        self.append(self.status)

        self.label = Gtk.Label(
            xalign=0,
            wrap=True,
            wrap_mode=Pango.WrapMode.WORD_CHAR,
            selectable=True,
            max_width_chars=34,
            visible=False,
        )
        self.append(self.label)

    def add_text(self, delta: str) -> None:
        self.set_text(self.text + delta)

    def set_text(self, text: str) -> None:
        self.text = text
        self.label.set_markup(to_markup(text))
        self.label.set_visible(bool(text))

    def set_status(self, status: str | None) -> None:
        self.status.set_label(status or "")
        self.status.set_visible(bool(status))


class AssistantWindow(Adw.ApplicationWindow):
    def __init__(self, app: Adw.Application):
        super().__init__(
            application=app,
            title="Assistant",
            default_width=460,
            default_height=720,
            hide_on_close=True,
        )
        self.assistant = Assistant()
        self.busy = False
        self.add_css_class("assistant")

        header = Adw.HeaderBar(title_widget=Adw.WindowTitle(title="アシスタント"))
        header.add_css_class("flat")
        new_button = Gtk.Button(icon_name="document-edit-symbolic", tooltip_text="新しい会話")
        new_button.add_css_class("flat")
        new_button.connect("clicked", lambda *_: self.new_conversation())
        header.pack_end(new_button)
        account_button = Gtk.Button(
            icon_name="avatar-default-symbolic", tooltip_text="Claude のアカウント"
        )
        account_button.add_css_class("flat")
        account_button.connect("clicked", lambda *_: self.open_login())
        header.pack_end(account_button)

        self.message_box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL,
            spacing=10,
            margin_top=12,
            margin_bottom=12,
            margin_start=12,
            margin_end=12,
        )
        self.scroller = Gtk.ScrolledWindow(
            vexpand=True,
            hscrollbar_policy=Gtk.PolicyType.NEVER,
            child=Adw.Clamp(maximum_size=720, child=self.message_box),
        )

        self.stack = Gtk.Stack(transition_type=Gtk.StackTransitionType.CROSSFADE)
        self.stack.add_named(self._build_empty_page(), "empty")
        self.stack.add_named(self.scroller, "chat")
        self.stack.add_named(self._build_login_page(), "login")

        self.entry = Gtk.Entry(hexpand=True, placeholder_text="Claude にたずねる…")
        self.entry.connect("activate", lambda *_: self.send(self.entry.get_text()))
        self.send_button = Gtk.Button(icon_name="go-up-symbolic", tooltip_text="送信")
        self.send_button.add_css_class("send")
        self.send_button.connect("clicked", lambda *_: self.send(self.entry.get_text()))
        # 入力欄と送信ボタンを、角の丸い1つの枠にまとめる
        field = Gtk.Box(spacing=8, valign=Gtk.Align.CENTER)
        field.add_css_class("composer")
        field.append(self.entry)
        field.append(self.send_button)
        composer = Adw.Clamp(
            maximum_size=720,
            child=field,
            margin_top=8,
            margin_bottom=14,
            margin_start=14,
            margin_end=14,
        )

        view = Adw.ToolbarView()
        view.add_top_bar(header)
        view.set_content(self.stack)
        view.add_bottom_bar(composer)
        self.set_content(view)

        # Esc で閉じる（会話は残る）
        shortcuts = Gtk.ShortcutController()
        shortcuts.add_shortcut(
            Gtk.Shortcut(
                trigger=Gtk.ShortcutTrigger.parse_string("Escape"),
                action=Gtk.CallbackAction.new(lambda *_: self.close() or True),
            )
        )
        self.add_controller(shortcuts)

        self.check_login()

    def _build_empty_page(self) -> Gtk.Widget:
        suggestions = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=8, halign=Gtk.Align.CENTER
        )
        for text in SUGGESTIONS:
            button = Gtk.Button(label=text)
            button.add_css_class("pill")
            button.connect("clicked", lambda _button, t=text: self.send(t))
            suggestions.append(button)
        return Adw.StatusPage(
            icon_name=APP_ID,
            title="何をしましょうか？",
            description="PCの操作や質問をどうぞ。Super + C でいつでも呼び出せます。",
            child=suggestions,
        )

    def _build_login_page(self) -> Gtk.Widget:
        buttons = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=8, halign=Gtk.Align.CENTER
        )
        login_button = Gtk.Button(label="ログイン")
        login_button.add_css_class("pill")
        login_button.add_css_class("suggested-action")
        login_button.connect("clicked", lambda *_: self.open_login())
        done_button = Gtk.Button(label="ログインしました")
        done_button.add_css_class("pill")
        done_button.connect("clicked", lambda *_: self.check_login())
        buttons.append(login_button)
        buttons.append(done_button)
        return Adw.StatusPage(
            icon_name=APP_ID,
            title="Claude にログイン",
            description="Pro / Max プランのアカウントでログインしてください。"
            "ターミナルが開くので、表示に従ってブラウザでログインします。",
            child=buttons,
        )

    # --- ログイン ---

    def check_login(self) -> None:
        def worker() -> None:
            status = login_status()
            GLib.idle_add(self._on_login_status, status)

        threading.Thread(target=worker, daemon=True).start()

    def _on_login_status(self, status: str) -> bool:
        if status != "ok":
            self.stack.set_visible_child_name("login")
        elif self.stack.get_visible_child_name() == "login":
            has_messages = self.message_box.get_first_child() is not None
            self.stack.set_visible_child_name("chat" if has_messages else "empty")
        return False

    def open_login(self) -> None:
        # Claude Code が入っていなければインストールしてから、ログイン画面を開く
        subprocess.Popen(["myos-claude-code", "login"])

    # --- 会話 ---

    def send(self, text: str) -> None:
        text = text.strip()
        if not text or self.busy:
            return
        self.entry.set_text("")
        play_sound("myos-tap")
        self._add_bubble("user").set_text(text)
        bubble = self._add_bubble("assistant")
        bubble.set_status("考えています…")
        self._set_busy(True)
        threading.Thread(target=self._worker, args=(text, bubble), daemon=True).start()

    def new_conversation(self) -> None:
        if self.busy:
            return
        self.assistant.reset()
        while child := self.message_box.get_first_child():
            self.message_box.remove(child)
        self.stack.set_visible_child_name("empty")
        self.entry.grab_focus()

    def _worker(self, text: str, bubble: MessageBubble) -> None:
        callbacks = Callbacks(
            on_text=lambda delta: GLib.idle_add(self._on_text, bubble, delta),
            on_tool=lambda name, _args: GLib.idle_add(
                bubble.set_status, TOOL_LABELS.get(name, name)
            ),
            confirm_command=self._confirm_from_worker,
        )
        error = None
        try:
            self.assistant.send(text, callbacks)
        except NotLoggedInError:
            error = "login"
        except AssistantError as assistant_error:
            error = f"エラーが発生しました: {assistant_error}"
        except Exception as unexpected:  # 画面が固まらないよう、何が起きても終了処理をする
            error = f"エラー: {unexpected}"
        GLib.idle_add(self._on_finished, bubble, error)

    def _on_text(self, bubble: MessageBubble, delta: str) -> bool:
        bubble.set_status(None)
        bubble.add_text(delta)
        self._scroll_to_end()
        return False

    def _on_finished(self, bubble: MessageBubble, error: str | None) -> bool:
        bubble.set_status(None)
        if error == "login":
            bubble.set_text("Claude にログインしていません。")
            self.stack.set_visible_child_name("login")
        elif error:
            bubble.set_text(bubble.text + ("\n\n" if bubble.text else "") + error)
        elif not bubble.text:
            bubble.set_text("完了しました。")
        self._set_busy(False)
        self._scroll_to_end()
        return False

    def _confirm_from_worker(self, command: str, reason: str) -> bool:
        """別スレッドから呼ばれる。確認ダイアログを出し、答えが出るまで待つ。"""
        answered = threading.Event()
        result = {"approved": False}

        def show() -> bool:
            preview = Gtk.Label(label=command, selectable=True, wrap=True, xalign=0)
            preview.add_css_class("monospace")
            preview.add_css_class("command-preview")
            dialog = Adw.AlertDialog(heading="このコマンドを実行しますか？", body=reason)
            dialog.set_extra_child(preview)
            dialog.add_response("cancel", "キャンセル")
            dialog.add_response("run", "実行する")
            dialog.set_response_appearance("run", Adw.ResponseAppearance.SUGGESTED)
            dialog.set_default_response("cancel")
            dialog.set_close_response("cancel")

            def on_response(_dialog: Adw.AlertDialog, response: str) -> None:
                result["approved"] = response == "run"
                answered.set()

            dialog.connect("response", on_response)
            self.present()
            dialog.present(self)
            return False

        GLib.idle_add(show)
        answered.wait()
        return result["approved"]

    # --- 表示まわり ---

    def _add_bubble(self, role: str) -> MessageBubble:
        self.stack.set_visible_child_name("chat")
        bubble = MessageBubble(role)
        self.message_box.append(bubble)
        self._scroll_to_end()
        return bubble

    def _scroll_to_end(self) -> None:
        def scroll() -> bool:
            adjustment = self.scroller.get_vadjustment()
            adjustment.set_value(adjustment.get_upper() - adjustment.get_page_size())
            return False

        GLib.idle_add(scroll)

    def _set_busy(self, busy: bool) -> None:
        self.busy = busy
        self.entry.set_sensitive(not busy)
        self.send_button.set_sensitive(not busy)
        if not busy:
            self.entry.grab_focus()


class AssistantApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.HANDLES_COMMAND_LINE)

    def do_command_line(self, command_line: Gio.ApplicationCommandLine) -> int:
        # `myos-assistant --ask "質問"` で開くと、その質問をすぐに送る（ホーム画面のウィジェットから使う）
        args = command_line.get_arguments()[1:]
        self.activate()
        if len(args) >= 2 and args[0] == "--ask":
            window = self.props.active_window
            if isinstance(window, AssistantWindow):
                window.send(" ".join(args[1:]))
        return 0

    def do_startup(self) -> None:
        Adw.Application.do_startup(self)
        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def do_activate(self) -> None:
        # 2回目以降の起動（Super + C）では、既存のウィンドウを前に出すだけ
        window = self.props.active_window or AssistantWindow(self)
        if not window.is_visible():
            play_sound("myos-assistant")
        window.present()
        if isinstance(window, AssistantWindow):
            window.entry.grab_focus()


if __name__ == "__main__":
    sys.exit(AssistantApp().run(sys.argv))
