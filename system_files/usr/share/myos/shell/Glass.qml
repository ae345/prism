// ソフトライトガラスの板。後ろのぼかしは Hyprland の layerrule（blur）が担当する。
import QtQuick

Rectangle {
    id: root

    radius: Theme.radiusWidget
    border.width: 1
    border.color: Theme.glassRim
    gradient: Gradient {
        GradientStop { position: 0; color: Theme.glassTop }
        GradientStop { position: 1; color: Theme.glassBottom }
    }

    // 上からのやわらかい光
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 1
        height: parent.height * 0.45
        radius: root.radius - 1
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.glassShine }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
