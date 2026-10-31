// 日付のウィジェット。押すとカレンダーアプリを開く。
import QtQuick
import Quickshell

Glass {
    id: root

    readonly property var weekdays: ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 24
        spacing: 0

        ShadowText {
            text: root.weekdays[clock.date.getDay()]
            color: "#FF8A8A"
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        ShadowText {
            text: clock.date.getDate()
            font.pixelSize: 72
            font.weight: Font.ExtraLight
            font.letterSpacing: -3
        }
    }

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 10

        Rectangle {
            width: 4
            height: 34
            radius: 2
            color: Theme.cyan
        }

        Column {
            ShadowText {
                text: (clock.date.getMonth() + 1) + "月" + clock.date.getDate() + "日"
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            ShadowText {
                text: "カレンダーを開く"
                opacity: 0.8
                font.pixelSize: 12
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Apps.launch("org.gnome.Calendar")
    }
}
