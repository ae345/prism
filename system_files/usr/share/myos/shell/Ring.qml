// 「このPC」ウィジェットの丸いメーター
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real value: 0          // 0〜1
    property color color: Theme.green
    property string label: ""
    property string valueText: ""

    implicitWidth: 92
    implicitHeight: 92

    Behavior on value {
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.25)
            strokeWidth: 8
            fillColor: Qt.rgba(0, 0, 0, 0.1)
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.width / 2 - 6; radiusY: root.height / 2 - 6
                startAngle: 0; sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: 8
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.width / 2 - 6; radiusY: root.height / 2 - 6
                startAngle: -90; sweepAngle: Math.max(0.5, 360 * root.value)
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: Qt.rgba(1, 1, 1, 0.8)
            font.family: Theme.font
            font.pixelSize: 11
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.valueText
            color: "white"
            font.family: Theme.font
            font.pixelSize: 17
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }
}
