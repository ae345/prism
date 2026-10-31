// 大きなフォルダ。中のアイコンを開かずにそのまま押せる。
import QtQuick

Item {
    id: root

    property string title: "ツール"
    property var apps: []

    // 中のアイコンが長押しされたとき（位置はフォルダ内の座標）
    signal heldApp(string appId, real x, real y)

    Glass {
        id: board
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: label.top
        anchors.bottomMargin: 8
        radius: Theme.radiusFolder

        Grid {
            anchors.centerIn: parent
            columns: 2
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: root.apps

                AppIcon {
                    id: folderIcon
                    required property string modelData
                    appId: modelData
                    size: 80
                    showLabel: false
                    onHeld: {
                        const point = folderIcon.mapToItem(root, folderIcon.width / 2, 0);
                        root.heldApp(modelData, point.x, point.y);
                    }
                }
            }
        }
    }

    ShadowText {
        id: label
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.title
        font.pixelSize: 13
        font.weight: Font.Medium
    }
}
