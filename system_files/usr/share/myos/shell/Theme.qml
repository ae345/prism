pragma Singleton

// 色・文字・角の丸み・動きの値。デザイン案の「デザインシステム」ボードと同じ値にしている。
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ライト／ダークは GNOME の設定（設定アプリやアシスタントで切り替え）に合わせる
    property bool dark: false

    readonly property string font: "Inter Variable"

    readonly property color accent: "#1E7BFF"
    readonly property color violet: "#8B5CFF"
    readonly property color pink: "#FF4F8B"
    readonly property color red: "#FF4D4F"
    readonly property color orange: "#FF8A3D"
    readonly property color yellow: "#FFC93D"
    readonly property color green: "#2FD27A"
    readonly property color cyan: "#22C3F0"
    readonly property color ink: "#1D1D1F"

    // ソフトライトガラス：すりガラス寄りで、壁紙の色（ピンク）をうっすら拾う
    readonly property color glassTop: dark ? Qt.rgba(0.27, 0.24, 0.43, 0.42) : Qt.rgba(1, 1, 1, 0.32)
    readonly property color glassBottom: dark ? Qt.rgba(0.12, 0.1, 0.24, 0.36) : Qt.rgba(1, 0.88, 0.96, 0.16)
    readonly property color glassRim: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.3)
    readonly property color glassShine: dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.24)

    readonly property int radiusWidget: 30
    readonly property int radiusFolder: 34
    readonly property int radiusDock: 32

    // 動き（ミリ秒）
    readonly property int springMs: 520
    readonly property int panelMs: 440
    readonly property int fadeMs: 200

    readonly property string wallpaper: dark
        ? "file:///usr/share/backgrounds/myos/myos-dark.svg"
        : "file:///usr/share/backgrounds/myos/myos-light.svg"

    Process {
        id: readScheme
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.dark = this.text.indexOf("dark") >= 0
        }
    }

    // 設定が変わったときに追いかける（数秒おきに確認するだけの簡単な方法）
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: readScheme.running = true
    }
}
