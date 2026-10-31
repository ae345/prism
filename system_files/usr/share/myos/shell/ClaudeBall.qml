// Claude ボール：画面の右端に浮かぶ光る玉。押すと、いまの画面やコピーした文章をもとに
// Claude にできることを選べる（HyperOS 4 の Inspiration Ball を Claude で置き換えたもの）。
// 全画面のゲームや動画のあいだは隠れる。コントロールセンターで出し入れできる。
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    property bool open: false
    property bool capturing: false
    property string clipboard: ""
    readonly property string windowTitle: Hyprland.activeToplevel && !Apps.onHome ? Hyprland.activeToplevel.title : ""

    anchors.right: true
    margins.right: 12
    implicitWidth: 400
    implicitHeight: 360
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Session.ballEnabled && !Apps.fullscreen && !Session.locked && !capturing
    mask: Region { item: window.open ? whole : ball }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "myos-ball"

    onOpenChanged: if (open) readClipboard.running = true

    Item {
        id: whole
        anchors.fill: parent
    }

    // ---- 動作

    function ask(text) {
        open = false;
        Apps.ask(text);
    }

    function askAboutScreen() {
        open = false;
        capturing = true;
        // ボールとメニューが消えてから撮る
        captureDelay.restart();
    }

    Timer {
        id: captureDelay
        interval: 300
        onTriggered: capture.running = true
    }

    Process {
        id: capture
        command: ["sh", "-c", "mkdir -p \"$HOME/.cache/myos\" && grim \"$HOME/.cache/myos/screen.png\""]
        onExited: (code, status) => {
            window.capturing = false;
            if (code !== 0)
                return;
            Sound.play("screen-capture");
            let prompt = "今の画面のスクリーンショットを ~/.cache/myos/screen.png に保存しました。"
                + "Read ツールで画像を見て、この画面で私が次にやりたそうなことを短く3つ提案し、すぐ手伝えるものは手伝ってください。";
            if (window.windowTitle.length > 0)
                prompt += "（表示中のウィンドウ: " + window.windowTitle + "）";
            Apps.ask(prompt);
        }
    }

    Process {
        id: readClipboard
        command: ["sh", "-c", "wl-paste --no-newline --type text 2>/dev/null | head -c 8000"]
        stdout: StdioCollector {
            onStreamFinished: window.clipboard = this.text
        }
    }

    // ---- 見た目

    // メニューの外を押すと閉じる
    MouseArea {
        anchors.fill: parent
        enabled: window.open
        onClicked: window.open = false
    }

    Rectangle {
        id: card
        anchors.right: ball.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 316
        height: column.implicitHeight + 32
        radius: 26
        color: Qt.rgba(0.98, 0.98, 0.99, 0.9)
        opacity: window.open ? 1 : 0
        scale: window.open ? 1 : 0.6
        transformOrigin: Item.Right
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: Theme.fadeMs }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.panelMs; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 8

            Text {
                text: window.windowTitle.length > 0 ? "いま: " + window.windowTitle : "Claude ボール"
                width: parent.width
                elide: Text.ElideRight
                color: "#8a8a93"
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            BallAction {
                text: "この画面について聞く"
                primary: true
                onClicked: window.askAboutScreen()
            }

            BallAction {
                visible: window.clipboard.length > 0
                text: "コピーした文章を要約"
                detail: window.clipboard.replace(/\s+/g, " ").slice(0, 40)
                onClicked: window.ask("次の文章を日本語で短く要約してください。\n\n" + window.clipboard)
            }

            BallAction {
                visible: window.clipboard.length > 0
                text: "コピーした文章を翻訳"
                onClicked: window.ask("次の文章を翻訳してください。日本語なら英語に、それ以外なら日本語にしてください。\n\n" + window.clipboard)
            }

            BallAction {
                text: "Claude を開く"
                onClicked: window.ask("")
            }
        }
    }

    Rectangle {
        id: ball
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 56
        height: 56
        radius: 28
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.5)
        opacity: ballMouse.containsMouse || window.open ? 1 : 0.85
        gradient: Gradient {
            GradientStop { position: 0; color: "#8F9BFF" }
            GradientStop { position: 0.6; color: "#B45BFF" }
            GradientStop { position: 1; color: "#FF6FD8" }
        }
        scale: ballMouse.pressed ? 0.88 : 1

        Behavior on scale {
            SpringAnimation { spring: 5; damping: 0.25 }
        }

        // ゆっくり息をするように光る
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.55) }
                GradientStop { position: 0.5; color: "transparent" }
            }
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 0.6; to: 1; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0.6; duration: 1800; easing.type: Easing.InOutSine }
            }
        }

        Image {
            anchors.centerIn: parent
            width: 26
            height: 26
            source: "icons/sparkle.svg"
            sourceSize: Qt.size(52, 52)
        }

        MouseArea {
            id: ballMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sound.play(window.open ? "myos-close" : "myos-assistant");
                window.open = !window.open;
            }
        }
    }

    component BallAction: Rectangle {
        id: action
        property string text: ""
        property string detail: ""
        property bool primary: false
        signal clicked

        width: parent.width
        height: detail.length > 0 ? 56 : 44
        radius: 14
        color: primary ? "#EEF4FF" : (actionMouse.pressed ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(0, 0, 0, 0.05))

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: action.text
                color: action.primary ? Theme.accent : Theme.ink
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: action.primary ? Font.DemiBold : Font.Medium
            }
            Text {
                visible: action.detail.length > 0
                width: parent.width
                text: "「" + action.detail + "…」"
                elide: Text.ElideRight
                color: "#8a8a93"
                font.family: Theme.font
                font.pixelSize: 12
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }
    }
}
