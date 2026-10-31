// 画面上部中央の黒い錠剤（Hyper Island 風）。
// 通知が届くと大きく広がり、音楽を再生中は小さく表示して、押すと操作パネルに広がる。
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    readonly property var notification: Notifs.latest
    property bool mediaExpanded: false

    readonly property string mode: notification ? "notify"
        : mediaExpanded && Media.player ? "media"
        : Media.playing ? "compact" : "hidden"

    anchors.top: true
    margins.top: 3
    implicitWidth: 520
    implicitHeight: 150
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: mode !== "hidden" || pill.width > 40
    // 錠剤の外側はクリックが下に抜けるようにする
    mask: Region { item: pill }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "myos-island"

    onModeChanged: if (mode === "hidden") mediaExpanded = false

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: window.mode === "notify" ? 480 : window.mode === "media" ? 440 : window.mode === "compact" ? 230 : 34
        height: window.mode === "notify" ? 92 : window.mode === "media" ? 132 : 34
        radius: Math.min(height / 2, 40)
        color: "black"
        opacity: window.mode === "hidden" ? 0 : 1
        clip: true

        Behavior on width {
            NumberAnimation { duration: Theme.springMs; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        Behavior on height {
            NumberAnimation { duration: Theme.springMs; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.fadeMs }
        }

        // 通知
        Row {
            visible: window.mode === "notify" && window.notification !== null
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 48
                source: window.notification ? Notifs.iconFor(window.notification) : ""
                sourceSize: Qt.size(96, 96)
                fillMode: Image.PreserveAspectFit
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 62
                spacing: 2

                Text {
                    width: parent.width
                    text: window.notification ? window.notification.appName : ""
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.family: Theme.font
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: window.notification ? window.notification.summary : ""
                    color: "white"
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: window.notification ? window.notification.body : ""
                    color: Qt.rgba(1, 1, 1, 0.8)
                    font.family: Theme.font
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                }
            }
        }

        // 音楽（小さい表示）
        Row {
            visible: window.mode === "compact"
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 12
            spacing: 8

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                source: Media.player && Media.player.trackArtUrl ? Media.player.trackArtUrl : "icons/music.svg"
                sourceSize: Qt.size(44, 44)
                fillMode: Image.PreserveAspectCrop
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 22 - 30 - 16
                text: Media.player ? Media.player.trackTitle : ""
                color: "white"
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            // 再生中を表す、上下に動く3本の線
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        radius: 1.5
                        color: Theme.green
                        height: 6
                        SequentialAnimation on height {
                            running: Media.playing && window.mode === "compact"
                            loops: Animation.Infinite
                            NumberAnimation { to: 14 - index * 3; duration: 260 + index * 90; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 5; duration: 260 + index * 90; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }

        // 音楽（広げた操作パネル）
        Item {
            visible: window.mode === "media"
            anchors.fill: parent
            anchors.margins: 18

            Image {
                id: art
                width: 64
                height: 64
                source: Media.player && Media.player.trackArtUrl ? Media.player.trackArtUrl : "icons/music.svg"
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectCrop
            }

            Column {
                anchors.left: art.right
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.verticalCenter: art.verticalCenter
                Text {
                    width: parent.width
                    text: Media.player ? Media.player.trackTitle : ""
                    color: "white"
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: Media.player ? Media.player.trackArtist : ""
                    color: Qt.rgba(1, 1, 1, 0.65)
                    font.family: Theme.font
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }

            Row {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 40

                MediaButton { icon: "icons/prev.svg"; onClicked: Media.player.previous() }
                MediaButton {
                    icon: Media.playing ? "icons/pause.svg" : "icons/play.svg"
                    size: 30
                    onClicked: Media.player.togglePlaying()
                }
                MediaButton { icon: "icons/next.svg"; onClicked: Media.player.next() }
            }
        }

        MouseArea {
            anchors.fill: parent
            // 操作パネルのボタンの邪魔をしないよう、広げた後は背景の押下だけを受ける
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (window.mode === "notify") {
                    Notifs.activate(window.notification);
                    Notifs.latest = null;
                } else if (window.mode === "compact") {
                    Sound.play("myos-tap");
                    window.mediaExpanded = true;
                } else if (window.mode === "media") {
                    window.mediaExpanded = false;
                }
            }
        }
    }
}
