// ホーム画面：ウィジェット、アプリの並び、大きなフォルダ、検索ボタン。
// デザイン案と同じ 1440×960 の座標で並べ、画面の大きさに合わせて全体を拡大・縮小する。
// ウィンドウより奥（Bottom レイヤー）にあるので、アプリを開くと隠れる。
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "myos-home"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property real designWidth: 1440
    readonly property real designHeight: 960
    readonly property real fit: Math.min(width / designWidth, height / designHeight)

    // 列の幅と行の位置（デザイン案のグリッドと同じ）
    readonly property real left: 72
    readonly property real column: 162
    readonly property real widgetTop: 64
    readonly property real widgetHeight: 306
    readonly property var rowTop: [384, 536]

    // ホームに戻ったとき、少し大きい所からふわっと定位置に収まる
    property real enter: Apps.onHome ? 1 : 0
    Behavior on enter {
        NumberAnimation { duration: Theme.springMs; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }

    Item {
        id: canvas
        width: window.designWidth
        height: window.designHeight
        x: (window.width - width * window.fit) / 2
        y: (window.height - height * window.fit) / 2
        opacity: Math.max(0, Math.min(1, window.enter))
        transform: [
            Scale {
                origin.x: canvas.width / 2
                origin.y: canvas.height / 2
                xScale: 1.06 - 0.06 * window.enter
                yScale: 1.06 - 0.06 * window.enter
            },
            Scale {
                xScale: window.fit
                yScale: window.fit
            }
        ]

        CalendarWidget {
            x: window.left + 14
            y: window.widgetTop
            width: window.column * 2 - 28
            height: window.widgetHeight
        }

        ClaudeWidget {
            x: window.left + window.column * 2 + 14
            y: window.widgetTop
            width: window.column * 4 - 28
            height: window.widgetHeight
        }

        StatsWidget {
            x: window.left + window.column * 6 + 14
            y: window.widgetTop
            width: window.column * 2 - 28
            height: window.widgetHeight
        }

        Repeater {
            model: Apps.grid

            AppIcon {
                required property string modelData
                required property int index
                appId: modelData
                width: window.column
                x: window.left + window.column * (index % 6) + (window.column - width) / 2
                y: window.rowTop[Math.floor(index / 6)] + 2
                onHeld: menu.show(modelData, x + width / 2, y)
            }
        }

        Folder {
            id: folder
            x: window.left + window.column * 6 + 14
            y: window.rowTop[0]
            width: window.column * 2 - 28
            height: 290
            apps: Apps.folder
            onHeldApp: (appId, px, py) => menu.show(appId, folder.x + px, folder.y + py)
        }

        Rectangle {
            id: search
            anchors.horizontalCenter: parent.horizontalCenter
            y: 790
            width: searchRow.implicitWidth + 30
            height: 32
            radius: 16
            color: Qt.rgba(1, 1, 1, searchMouse.pressed ? 0.3 : 0.18)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.3)

            Row {
                id: searchRow
                anchors.centerIn: parent
                spacing: 6

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    source: "icons/search.svg"
                    sourceSize: Qt.size(28, 28)
                }

                ShadowText {
                    text: "検索"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: searchMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Session.toggleLibrary()
            }
        }

        HomeMenu {
            id: menu
        }
    }

    // ほかの画面に移ったら、開いていたメニューは閉じる
    Connections {
        target: Apps
        function onOnHomeChanged() {
            menu.hide();
        }
    }
}
