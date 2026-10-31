// Claude のウィジェット。ここに打ち込むと、アシスタントが開いてそのまま質問が送られる。
import QtQuick
import Quickshell

Glass {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    readonly property string greeting: clock.hours < 5 ? "こんばんは"
        : clock.hours < 11 ? "おはようございます"
        : clock.hours < 18 ? "こんにちは" : "こんばんは"

    function send(text) {
        Apps.ask(text);
        field.text = "";
    }

    Row {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 26
        spacing: 12

        Image {
            width: 44
            height: 44
            source: Quickshell.iconPath("io.github.myos.Assistant")
            sourceSize: Qt.size(88, 88)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            ShadowText {
                text: root.greeting
                font.pixelSize: 21
                font.weight: Font.DemiBold
            }
            ShadowText {
                text: "Claude が PC の操作も手伝います"
                opacity: 0.85
                font.pixelSize: 13
            }
        }
    }

    Rectangle {
        id: box
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 6
        anchors.leftMargin: 26
        anchors.rightMargin: 26
        height: 54
        radius: 27
        color: Qt.rgba(1, 1, 1, field.activeFocus ? 0.34 : 0.22)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.38)

        Behavior on color {
            ColorAnimation { duration: Theme.fadeMs }
        }

        TextInput {
            id: field
            anchors.left: parent.left
            anchors.right: sendButton.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 22
            anchors.rightMargin: 10
            color: "white"
            selectionColor: Qt.rgba(1, 1, 1, 0.35)
            font.family: Theme.font
            font.pixelSize: 16
            clip: true
            onAccepted: root.send(text)

            Text {
                visible: field.text.length === 0 && !field.inputMethodComposing
                text: "Claude にたずねる…"
                color: Qt.rgba(1, 1, 1, 0.75)
                font: field.font
            }
        }

        Rectangle {
            id: sendButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 7
            width: 40
            height: 40
            radius: 20
            color: "white"
            scale: sendMouse.pressed ? 0.88 : 1

            Behavior on scale {
                SpringAnimation { spring: 5; damping: 0.3 }
            }

            Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                source: "icons/arrow-up.svg"
                sourceSize: Qt.size(36, 36)
            }

            MouseArea {
                id: sendMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.send(field.text)
            }
        }
    }

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 26
        spacing: 8

        Repeater {
            model: ["ダークモードにして", "ストレージの空きは？", "今夜遊ぶゲームを選んで"]

            Rectangle {
                id: chip
                required property string modelData
                width: chipText.implicitWidth + 30
                height: 36
                radius: 18
                color: Qt.rgba(1, 1, 1, chipMouse.pressed ? 0.28 : 0.14)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.3)
                scale: chipMouse.pressed ? 0.94 : 1

                Behavior on scale {
                    SpringAnimation { spring: 5; damping: 0.3 }
                }

                ShadowText {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.modelData
                    font.pixelSize: 13
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.send(chip.modelData)
                }
            }
        }
    }
}
