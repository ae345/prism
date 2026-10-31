// 画面下に浮かぶ Dock。ホーム画面にいるときだけ出す（アプリを開くと隠れる）。
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    readonly property real fit: Math.min(screen.width / 1440, screen.height / 960)

    anchors.bottom: true
    margins.bottom: Math.round(18 * fit)
    implicitWidth: Math.ceil(bar.width * fit) + 2
    implicitHeight: Math.ceil(bar.height * fit) + 2
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Apps.onHome
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "myos-dock"

    Glass {
        id: bar
        width: icons.implicitWidth + 32
        height: 100
        radius: Theme.radiusDock
        transformOrigin: Item.TopLeft
        scale: window.fit

        // 出てくるとき、下から弾むように上がる
        property real rise: window.visible ? 0 : 1
        Behavior on rise {
            NumberAnimation { duration: Theme.springMs; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }
        transform: Translate { y: 40 * bar.rise }

        Row {
            id: icons
            anchors.centerIn: parent
            spacing: 18

            Repeater {
                model: Apps.dock

                AppIcon {
                    required property string modelData
                    appId: modelData
                    size: 74
                    showLabel: false
                    implicitWidth: 74
                    // Dock では長押しで外す
                    onHeld: Apps.toggleDock(modelData)
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 56
                color: Qt.rgba(1, 1, 1, 0.35)
            }

            // アプリライブラリ（すべてのアプリ）
            Rectangle {
                width: 74
                height: 74
                radius: 17
                color: Qt.rgba(1, 1, 1, libraryMouse.pressed ? 0.36 : 0.24)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.35)
                scale: libraryMouse.pressed ? 0.88 : 1

                Behavior on scale {
                    SpringAnimation { spring: 5; damping: 0.28 }
                }

                Grid {
                    anchors.centerIn: parent
                    columns: 2
                    spacing: 6

                    Repeater {
                        model: Apps.grid.slice(0, 4)

                        Image {
                            required property string modelData
                            readonly property var entry: DesktopEntries.byId(modelData)
                            width: 22
                            height: 22
                            source: entry ? Quickshell.iconPath(entry.icon, "application-x-executable") : ""
                            sourceSize: Qt.size(44, 44)
                        }
                    }
                }

                MouseArea {
                    id: libraryMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Session.toggleLibrary()
                }
            }
        }
    }
}
