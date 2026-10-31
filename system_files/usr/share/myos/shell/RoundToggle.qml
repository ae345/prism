// コントロールセンターの丸いトグル。
// オンは白いガラスに色つきの記号、オフは透明なガラスに白い記号（HyperOS の透明なトグル）。
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property bool on: false
    property color onColor: Theme.accent
    property string icon: ""
    property string label: ""
    property int size: 66

    signal toggled

    implicitWidth: size
    implicitHeight: size + (label.length > 0 ? 24 : 0)

    Rectangle {
        id: circle
        width: root.size
        height: root.size
        radius: root.size / 2
        anchors.horizontalCenter: parent.horizontalCenter
        color: root.on ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(1, 1, 1, 0.16)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.35)
        scale: mouse.pressed ? 0.9 : pulse

        property real pulse: 1

        Behavior on color {
            ColorAnimation { duration: Theme.fadeMs }
        }
        Behavior on scale {
            SpringAnimation { spring: 5; damping: 0.25; epsilon: 0.002 }
        }

        Image {
            anchors.centerIn: parent
            width: root.size * 0.42
            height: width
            source: root.icon
            sourceSize: Qt.size(width * 2, height * 2)
            layer.enabled: root.on
            layer.effect: MultiEffect {
                colorization: 1
                colorizationColor: root.onColor
            }
        }
    }

    Text {
        visible: root.label.length > 0
        anchors.top: circle.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.label
        color: "white"
        font.family: Theme.font
        font.pixelSize: 12
    }

    MouseArea {
        id: mouse
        anchors.fill: circle
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Sound.play(root.on ? "button-toggle-off" : "button-toggle-on");
            root.toggled();
        }
    }
}
