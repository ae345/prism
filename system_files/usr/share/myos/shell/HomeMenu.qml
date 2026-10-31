// アイコンを長押し（または右クリック）したときのメニュー。Dock への出し入れと、ホームから外す操作。
import QtQuick

Item {
    id: root

    property string appId: ""
    property bool shown: false

    anchors.fill: parent
    visible: shown || card.opacity > 0.01

    function show(id, x, y) {
        appId = id;
        card.x = Math.max(12, Math.min(width - card.width - 12, x - card.width / 2));
        card.y = Math.max(12, y - card.height - 10);
        shown = true;
    }

    function hide() {
        shown = false;
    }

    // メニューの外を押すと閉じる
    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        onClicked: root.hide()
    }

    Rectangle {
        id: card
        width: 220
        height: column.implicitHeight + 12
        radius: 18
        color: Qt.rgba(0.98, 0.98, 0.99, 0.9)
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.85
        transformOrigin: Item.Bottom

        Behavior on opacity {
            NumberAnimation { duration: Theme.fadeMs }
        }
        Behavior on scale {
            NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6

            MenuRow {
                text: Apps.inDock(root.appId) ? "Dock から外す" : "Dock に追加"
                onClicked: {
                    Apps.toggleDock(root.appId);
                    root.hide();
                }
            }
            MenuRow {
                text: "ホームから外す"
                destructive: true
                onClicked: {
                    Apps.removeFromHome(root.appId);
                    root.hide();
                }
            }
        }
    }

    component MenuRow: Rectangle {
        id: row
        property string text: ""
        property bool destructive: false
        signal clicked

        width: parent.width
        height: 44
        radius: 12
        color: rowMouse.pressed ? Qt.rgba(0, 0, 0, 0.08) : "transparent"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: row.text
            color: row.destructive ? Theme.red : Theme.ink
            font.family: Theme.font
            font.pixelSize: 15
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }
}
