pragma Singleton

// ホーム画面・フォルダ・Dock に並べるアプリと、起動・ホームに戻る処理。
// 並びは ~/.config/myos/home.json に保存する。まだ保存がなければ、下の候補から
// 入っている最初のものを使う（入っていなければ並べない）。
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property int gridLimit: 12   // 6 列 × 2 行

    readonly property var gridCandidates: [
        ["org.mozilla.firefox", "firefox"],
        ["org.gnome.Loupe", "org.gnome.Shotwell"],
        ["org.gnome.Calendar"],
        ["org.gnome.Geary", "org.mozilla.Thunderbird"],
        ["org.gnome.Music", "io.bassi.Amberol"],
        ["org.gnome.Weather"],
        ["io.github.kolunmi.Bazaar", "org.gnome.Software"],
        ["steam", "com.valvesoftware.Steam"],
        ["org.gnome.Showtime", "org.gnome.Totem"],
        ["myos-claude-code"],
        ["org.gnome.Nautilus"],
        ["org.gnome.Settings"]
    ]
    readonly property var folderCandidates: [
        ["org.gnome.Calculator"],
        ["org.gnome.clocks"],
        ["org.gnome.TextEditor"],
        ["org.gnome.Maps"]
    ]
    readonly property var dockCandidates: [
        ["org.mozilla.firefox", "firefox"],
        ["org.gnome.Nautilus"],
        ["steam", "com.valvesoftware.Steam"],
        ["io.github.myos.Assistant"],
        ["org.gnome.Ptyxis", "org.gnome.Terminal"]
    ]

    // 保存された並び（読み込むまでは null）
    property var savedGrid: null
    property var savedFolder: null
    property var savedDock: null

    readonly property var grid: available(savedGrid, gridCandidates).slice(0, gridLimit)
    readonly property var folder: available(savedFolder, folderCandidates).slice(0, 4)
    readonly property var dock: available(savedDock, dockCandidates).slice(0, 7)

    // すべてのアプリ（名前順）
    readonly property var all: DesktopEntries.applications.values
        .slice()
        .sort((a, b) => a.name.localeCompare(b.name, "ja"))

    function available(saved, candidates) {
        // applications を読むことで、アプリ一覧が読み込まれたときに並び直される
        const loaded = DesktopEntries.applications.values.length;
        if (saved)
            return saved.filter(id => DesktopEntries.byId(id) !== null);
        const ids = [];
        for (const options of candidates) {
            const found = options.find(id => DesktopEntries.byId(id) !== null);
            if (found)
                ids.push(found);
        }
        return loaded >= 0 ? ids : [];
    }

    // ---- 並びの変更（長押しメニューから使う）

    function inDock(id) {
        return dock.indexOf(id) >= 0;
    }

    function onHomeScreen(id) {
        return grid.indexOf(id) >= 0 || folder.indexOf(id) >= 0;
    }

    function toggleDock(id) {
        const list = dock.slice();
        const index = list.indexOf(id);
        if (index >= 0)
            list.splice(index, 1);
        else if (list.length < 7)
            list.push(id);
        save(grid, folder, list);
    }

    function addToHome(id) {
        if (onHomeScreen(id))
            return true;
        if (grid.length >= gridLimit)
            return false;
        save(grid.concat([id]), folder, dock);
        return true;
    }

    function removeFromHome(id) {
        save(grid.filter(x => x !== id), folder.filter(x => x !== id), dock);
    }

    function save(newGrid, newFolder, newDock) {
        savedGrid = newGrid.slice();
        savedFolder = newFolder.slice();
        savedDock = newDock.slice();
        const json = JSON.stringify({ grid: savedGrid, folder: savedFolder, dock: savedDock }, null, 2);
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$HOME/.config/myos\" && printf '%s\\n' \"$1\" > \"$HOME/.config/myos/home.json\"",
            "sh", json]);
        Sound.play("myos-tap");
    }

    Process {
        id: readLayout
        command: ["sh", "-c", "cat \"$HOME/.config/myos/home.json\" 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length === 0)
                    return;
                try {
                    const layout = JSON.parse(this.text);
                    root.savedGrid = Array.isArray(layout.grid) ? layout.grid : null;
                    root.savedFolder = Array.isArray(layout.folder) ? layout.folder : null;
                    root.savedDock = Array.isArray(layout.dock) ? layout.dock : null;
                } catch (error) {
                    console.warn("home.json を読めませんでした:", error);
                }
            }
        }
    }

    // ---- 起動など

    function launch(id) {
        const entry = DesktopEntries.byId(id);
        if (!entry)
            return;
        Sound.play("myos-open");
        if (id === "org.gnome.Settings") {
            // GNOME の設定アプリは GNOME 以外では起動を拒むので、GNOME として起動する
            Quickshell.execDetached({
                command: ["gnome-control-center"],
                environment: ({ XDG_CURRENT_DESKTOP: "GNOME" })
            });
            return;
        }
        entry.execute();
    }

    // アシスタントを開いて、質問をそのまま送る（呼び出し音はアシスタント側で鳴る）
    function ask(text) {
        const command = ["myos-assistant"];
        if (text && text.trim().length > 0)
            command.push("--ask", text.trim());
        Quickshell.execDetached(command);
    }

    function goHome() {
        Sound.play("myos-close");
        Hyprland.dispatch("workspace empty");
    }

    // いまのワークスペースにウィンドウがなければ「ホーム画面にいる」とみなす
    property int windowsHere: 0
    readonly property bool onHome: windowsHere === 0
    readonly property bool fullscreen: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.hasFullscreen

    function refresh() {
        const workspace = Hyprland.focusedWorkspace;
        windowsHere = workspace ? workspace.toplevels.values.length : 0;
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            Qt.callLater(root.refresh);
            settle.restart();
        }
    }

    // Hyprland 側の情報が更新されるのを少し待ってから、もう一度確かめる
    Timer {
        id: settle
        interval: 250
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
