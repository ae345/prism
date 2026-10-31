// アプリのアイコン（押すと少し縮んで、離すと弾んで戻る）
import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: root

    required property string appId
    property int size: 84
    property bool showLabel: true

    readonly property var entry: DesktopEntries.byId(appId)

    // 長押ししたとき（ホーム画面の並べ替えメニューを出す）
    signal held

    implicitWidth: size + 40
    implicitHeight: size + (showLabel ? 30 : 0)

    Image {
        id: icon
        width: root.size
        height: root.size
        anchors.horizontalCenter: parent.horizontalCenter
        source: root.entry ? Quickshell.iconPath(root.entry.icon, "application-x-executable") : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        smooth: true
        mipmap: true
        scale: mouse.pressed ? 0.88 : 1

        Behavior on scale {
            SpringAnimation { spring: 5; damping: 0.28; epsilon: 0.002 }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.26)
            shadowBlur: 0.7
            shadowVerticalOffset: 5
        }
    }

    ShadowText {
        visible: root.showLabel
        anchors.top: icon.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.entry ? root.entry.name : ""
        font.pixelSize: 13
        font.weight: Font.Medium
    }

    MouseArea {
        id: mouse
        anchors.fill: icon
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.held();
            else
                Apps.launch(root.appId);
        }
        onPressAndHold: {
            Sound.play("myos-tap");
            root.held();
        }
    }
}
