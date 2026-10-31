// コントロールセンターに並ぶ通知のカード。押すと開き、× で消す。
import QtQuick

Rectangle {
    id: root

    required property var notification

    height: content.implicitHeight + 28
    radius: 24
    color: Qt.rgba(0.98, 0.98, 0.99, 0.84)

    Row {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        Image {
            width: 40
            height: 40
            source: Notifs.iconFor(root.notification)
            sourceSize: Qt.size(80, 80)
            fillMode: Image.PreserveAspectFit
        }

        Column {
            width: parent.width - 40 - 12 - 28
            spacing: 2

            Text {
                width: parent.width
                text: root.notification.appName
                color: "#8a8a93"
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.notification.summary
                color: Theme.ink
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: root.notification.body
                color: "#3a3a40"
                font.family: Theme.font
                font.pixelSize: 14
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Notifs.activate(root.notification);
            Session.closeControlCenter();
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        width: 26
        height: 26
        radius: 13
        color: closeMouse.pressed ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(0, 0, 0, 0.07)

        Text {
            anchors.centerIn: parent
            text: "×"
            color: "#6e6e76"
            font.pixelSize: 16
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.notification.dismiss()
        }
    }
}
