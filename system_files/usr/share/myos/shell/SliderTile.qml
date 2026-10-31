// 横長のスライダー（音量・明るさ）。白い部分が今の値で、つかんで左右に動かす。
import QtQuick

Glass {
    id: root

    property real value: 0      // 0〜1
    property string icon: ""

    signal moved(real value)

    radius: height / 2
    clip: true

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(root.height, parent.width * root.value)
        radius: root.radius
        color: "white"

        Behavior on width {
            enabled: !drag.pressed
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
    }

    Image {
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        source: root.icon
        sourceSize: Qt.size(52, 52)
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function update(x) {
            root.moved(Math.max(0, Math.min(1, x / width)));
        }
        onPressed: mouse => update(mouse.x)
        onPositionChanged: mouse => update(mouse.x)
    }
}
