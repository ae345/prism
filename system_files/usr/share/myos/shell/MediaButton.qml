// 再生・前・次などの小さなボタン
import QtQuick

Item {
    id: root

    property string icon: ""
    property int size: 26

    signal clicked

    implicitWidth: size + 12
    implicitHeight: size + 12

    Image {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        source: root.icon
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        scale: mouse.pressed ? 0.85 : 1

        Behavior on scale {
            SpringAnimation { spring: 5; damping: 0.3 }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Sound.play("myos-tap");
            root.clicked();
        }
    }
}
