// アプリを開いているときだけ、画面下に出るバー。押すとホーム画面に戻る。
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    anchors.bottom: true
    implicitWidth: 260
    implicitHeight: 22
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: !Apps.onHome
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "myos-homebar"

    Rectangle {
        anchors.centerIn: parent
        width: mouse.containsMouse ? 180 : 160
        height: 6
        radius: 3
        color: Qt.rgba(0.1, 0.1, 0.12, 0.6)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.55)

        Behavior on width {
            NumberAnimation { duration: 260; easing.type: Easing.OutBack }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Apps.goHome()
    }
}
