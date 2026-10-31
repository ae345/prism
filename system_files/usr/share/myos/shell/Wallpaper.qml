// 一番奥の壁紙。アプリを開くと少しだけ拡大して、奥行きを出す。
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "#1a1660"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "myos-wallpaper"

    Image {
        anchors.fill: parent
        source: Theme.wallpaper
        sourceSize: Qt.size(window.width, window.height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        scale: Apps.onHome ? 1 : 1.06

        Behavior on scale {
            NumberAnimation { duration: 700; easing.type: Easing.OutCubic }
        }
    }
}
