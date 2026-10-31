// コントロールセンター。右上のステータス（音量・Wi-Fi）を押すか Super + A で開く。
// 左に大きな時計と通知、右にトグル・音楽・スライダー・電源を並べる。背景はぼかして暗くする。
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    readonly property bool open: Session.controlCenterOpen
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var adapter: Bluetooth.defaultAdapter

    // 明るさはノートPCなど、明るさを変えられる画面があるときだけ出す
    property bool hasBacklight: false
    property real brightness: 0.7

    // 電源ボタンは、誤操作を防ぐため 2 回押しで実行する
    property string armed: ""

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || backdrop.opacity > 0.01
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "myos-control"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        armed = "";
        if (open)
            readBrightness.running = true;
    }

    PwObjectTracker {
        objects: window.sink ? [window.sink] : []
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Process {
        id: readBrightness
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // 例: intel_backlight,backlight,120,40%,300
                const parts = this.text.trim().split(",");
                window.hasBacklight = parts.length >= 4 && parts[1] === "backlight";
                if (window.hasBacklight)
                    window.brightness = parseInt(parts[3]) / 100;
            }
        }
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: window.armed = ""
    }

    function power(action) {
        if (armed !== action) {
            armed = action;
            Sound.play("dialog-warning");
            disarm.restart();
            return;
        }
        if (action === "logout")
            Session.logout();
        else if (action === "reboot")
            Session.reboot();
        else if (action === "poweroff")
            Session.powerOff();
    }

    // ぼかした背景。押すと閉じる
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.04, 0.12, 0.32)
        opacity: window.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Session.closeControlCenter()
        }
    }

    Item {
        anchors.fill: parent
        focus: window.open
        Keys.onEscapePressed: Session.closeControlCenter()
    }

    // 左：時計と通知
    Column {
        id: left
        x: 80
        y: 70
        width: 470
        spacing: 12
        opacity: backdrop.opacity
        transform: Translate { y: (1 - backdrop.opacity) * -20 }

        Text {
            text: (clock.date.getMonth() + 1) + "月" + clock.date.getDate() + "日 " + ["日", "月", "火", "水", "木", "金", "土"][clock.date.getDay()] + "曜日"
            color: "white"
            font.family: Theme.font
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }

        Text {
            text: Qt.formatDateTime(clock.date, "H:mm")
            color: "white"
            font.family: Theme.font
            font.pixelSize: 104
            font.weight: Font.DemiBold
            font.letterSpacing: -4
            font.features: { "tnum": 1 }
        }

        Item {
            width: parent.width
            height: 30
            visible: Notifs.list.length > 0

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "通知 " + Notifs.list.length + "件"
                color: "white"
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "すべて消去"
                color: "white"
                opacity: clearMouse.pressed ? 0.6 : 0.9
                font.family: Theme.font
                font.pixelSize: 14

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.clearAll()
                }
            }
        }

        ListView {
            width: parent.width
            height: Math.min(contentHeight, window.height - 320)
            spacing: 10
            clip: true
            model: Notifs.list.slice().reverse()
            delegate: NotificationCard {
                required property var modelData
                notification: modelData
                width: ListView.view.width
            }
        }

        Text {
            visible: Notifs.list.length === 0
            text: "通知はありません"
            color: Qt.rgba(1, 1, 1, 0.75)
            font.family: Theme.font
            font.pixelSize: 15
        }
    }

    // 右：コントロール
    Column {
        id: panel
        anchors.right: parent.right
        anchors.rightMargin: 40
        y: 50
        width: 440
        spacing: 16
        opacity: backdrop.opacity
        transformOrigin: Item.TopRight
        scale: window.open ? 1 : 0.92

        Behavior on scale {
            NumberAnimation { duration: Theme.panelMs; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }

        Row {
            spacing: 16

            // 通信・モードの 4 つのトグル
            Glass {
                width: 212
                height: 212

                Grid {
                    anchors.centerIn: parent
                    columns: 2
                    spacing: 22

                    RoundToggle {
                        icon: "icons/wifi.svg"
                        on: Networking.wifiEnabled
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                    RoundToggle {
                        icon: "icons/bluetooth.svg"
                        on: window.adapter !== null && window.adapter.enabled
                        onToggled: if (window.adapter) window.adapter.enabled = !window.adapter.enabled
                    }
                    RoundToggle {
                        icon: "icons/moon.svg"
                        onColor: Theme.violet
                        on: Session.doNotDisturb
                        onToggled: Session.doNotDisturb = !Session.doNotDisturb
                    }
                    RoundToggle {
                        icon: "icons/game.svg"
                        onColor: Theme.orange
                        on: Session.gameMode
                        onToggled: Session.setGameMode(!Session.gameMode)
                    }
                }
            }

            // 再生中の音楽
            Glass {
                width: 212
                height: 212

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    Row {
                        spacing: 12
                        Image {
                            width: 56
                            height: 56
                            source: Media.player && Media.player.trackArtUrl ? Media.player.trackArtUrl : Quickshell.iconPath("org.gnome.Music", "audio-x-generic")
                            sourceSize: Qt.size(112, 112)
                            fillMode: Image.PreserveAspectCrop
                        }
                        Column {
                            width: 104
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                width: parent.width
                                text: Media.player ? Media.player.trackTitle : "再生していません"
                                color: "white"
                                font.family: Theme.font
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: Media.player ? (Media.player.trackArtist || Media.player.identity) : ""
                                color: Qt.rgba(1, 1, 1, 0.7)
                                font.family: Theme.font
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 14
                        enabled: Media.player !== null
                        opacity: enabled ? 1 : 0.4

                        MediaButton { icon: "icons/prev.svg"; onClicked: Media.player.previous() }
                        MediaButton {
                            icon: Media.playing ? "icons/pause.svg" : "icons/play.svg"
                            size: 30
                            onClicked: Media.player.togglePlaying()
                        }
                        MediaButton { icon: "icons/next.svg"; onClicked: Media.player.next() }
                    }
                }
            }
        }

        SliderTile {
            width: parent.width
            height: 64
            icon: "icons/volume-gray.svg"
            value: window.sink && window.sink.audio ? window.sink.audio.volume : 0
            onMoved: value => {
                if (window.sink && window.sink.audio)
                    window.sink.audio.volume = value;
            }
        }

        SliderTile {
            visible: window.hasBacklight
            width: parent.width
            height: 64
            icon: "icons/sun.svg"
            value: window.brightness
            onMoved: value => {
                window.brightness = value;
                Quickshell.execDetached(["brightnessctl", "set", Math.max(5, Math.round(value * 100)) + "%"]);
            }
        }

        Row {
            spacing: 16

            RoundToggle {
                size: 98
                icon: "icons/contrast.svg"
                on: Theme.dark
                onColor: Theme.ink
                onToggled: Session.setDark(!Theme.dark)
            }
            RoundToggle {
                size: 98
                icon: "icons/screenshot.svg"
                onToggled: Session.screenshot()
            }
            RoundToggle {
                size: 98
                icon: "icons/lock.svg"
                onToggled: Session.lock()
            }
            RoundToggle {
                size: 98
                icon: "icons/sparkle.svg"
                on: Session.ballEnabled
                onColor: Theme.violet
                onToggled: Session.ballEnabled = !Session.ballEnabled
            }
        }

        // Claude を呼ぶ
        Rectangle {
            width: parent.width
            height: 82
            radius: 30
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.4)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(0.56, 0.61, 1, 0.9) }
                GradientStop { position: 0.55; color: Qt.rgba(0.71, 0.36, 1, 0.9) }
                GradientStop { position: 1; color: Qt.rgba(1, 0.44, 0.85, 0.9) }
            }
            scale: claudeMouse.pressed ? 0.97 : 1

            Behavior on scale {
                SpringAnimation { spring: 5; damping: 0.3 }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 48
                    source: Quickshell.iconPath("io.github.myos.Assistant")
                    sourceSize: Qt.size(96, 96)
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "Claude に話しかける"
                        color: "white"
                        font.family: Theme.font
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: "Super + C でも呼び出せます"
                        color: Qt.rgba(1, 1, 1, 0.9)
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                }
            }

            MouseArea {
                id: claudeMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Session.closeControlCenter();
                    Apps.ask("");
                }
            }
        }

        // 電源（2 回押しで実行）
        Row {
            spacing: 12

            Repeater {
                model: [
                    { action: "logout", icon: "icons/logout.svg", label: "ログアウト" },
                    { action: "reboot", icon: "icons/restart.svg", label: "再起動" },
                    { action: "poweroff", icon: "icons/power.svg", label: "電源を切る" }
                ]

                Rectangle {
                    id: powerButton
                    required property var modelData
                    readonly property bool isArmed: window.armed === modelData.action
                    width: (panel.width - 24) / 3
                    height: 52
                    radius: 26
                    color: isArmed ? Theme.red : Qt.rgba(1, 1, 1, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.3)

                    Behavior on color {
                        ColorAnimation { duration: Theme.fadeMs }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            source: powerButton.modelData.icon
                            sourceSize: Qt.size(36, 36)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: powerButton.isArmed ? "もう一度" : powerButton.modelData.label
                            color: "white"
                            font.family: Theme.font
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.power(powerButton.modelData.action)
                    }
                }
            }
        }
    }
}
