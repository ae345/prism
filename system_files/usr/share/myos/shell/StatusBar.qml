// 画面上のステータスバー：左に時刻と日付、右に音量とバッテリー（ノートPCのときだけ）
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: 34
    exclusiveZone: 34
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "myos-bar"

    readonly property var weekdays: ["日", "月", "火", "水", "木", "金", "土"]
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var battery: UPower.displayDevice

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PwObjectTracker {
        objects: window.sink ? [window.sink] : []
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 30
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        ShadowText {
            text: Qt.formatDateTime(clock.date, "H:mm")
            font.pixelSize: 15
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        ShadowText {
            text: (clock.date.getMonth() + 1) + "月" + clock.date.getDate() + "日(" + window.weekdays[clock.date.getDay()] + ")"
            font.pixelSize: 15
            font.weight: Font.Medium
        }
    }

    // 右側を押すとコントロールセンターが開く
    MouseArea {
        anchors.fill: status
        anchors.margins: -8
        cursorShape: Qt.PointingHandCursor
        onClicked: Session.toggleControlCenter()
    }

    Row {
        id: status
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Image {
            visible: Session.doNotDisturb
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: Session.gameMode ? "icons/game.svg" : "icons/moon.svg"
            sourceSize: Qt.size(32, 32)
        }

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            source: window.sink && window.sink.audio && window.sink.audio.muted ? "icons/volume-off.svg" : "icons/volume.svg"
            sourceSize: Qt.size(36, 36)
        }

        ShadowText {
            visible: window.sink !== null && window.sink.audio !== null
            text: window.sink && window.sink.audio ? Math.round(window.sink.audio.volume * 100) + "%" : ""
            font.pixelSize: 14
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Item { width: 6; height: 1 }

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            source: "icons/wifi.svg"
            sourceSize: Qt.size(36, 36)
        }

        // バッテリーはノートPCのときだけ表示する。値が 0〜1 か 0〜100 かは機種で違うので両方に対応
        ShadowText {
            visible: window.battery && window.battery.isLaptopBattery
            text: {
                if (!window.battery)
                    return "";
                const value = window.battery.percentage;
                return Math.round(value <= 1 ? value * 100 : value) + "%";
            }
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }
}
