// 壁紙の上でも読みやすいよう、うすい影をつけた白い文字
import QtQuick
import QtQuick.Effects

Text {
    color: "white"
    font.family: Theme.font
    renderType: Text.NativeRendering
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0.16, 0.04, 0.3, 0.35)
        shadowBlur: 0.35
        shadowVerticalOffset: 1
    }
}
