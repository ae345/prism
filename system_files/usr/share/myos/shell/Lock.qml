// ロック画面。Super + L かコントロールセンターの鍵ボタンでロックする。
// 縦に伸ばした大きな時計と、届いている通知の数、パスワード欄を出す。
// パスワードの確認は PAM（pam/password.conf）で行う。
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

Scope {
    id: root

    property string password: ""
    property string error: ""
    property bool checking: false

    function submit(text) {
        if (checking || text.length === 0)
            return;
        password = text;
        error = "";
        checking = true;
        pam.start();
    }

    Connections {
        target: Session
        function onLockedChanged() {
            if (Session.locked)
                Sound.play("myos-close");
        }
    }

    // 10 分さわらなければ自動でロックする（動画やゲームが画面の消灯を止めているあいだはロックしない）
    IdleMonitor {
        timeout: 600
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle)
                Session.lock();
        }
    }

    PamContext {
        id: pam
        configDirectory: "pam"
        config: "password.conf"

        onPamMessage: {
            if (responseRequired)
                respond(root.password);
        }

        onCompleted: result => {
            root.checking = false;
            root.password = "";
            if (result === PamResult.Success) {
                Sound.play("myos-open");
                Session.locked = false;
            } else {
                Sound.play("dialog-warning");
                root.error = "パスワードが違います";
            }
        }
    }

    WlSessionLock {
        id: lock
        locked: Session.locked

        WlSessionLockSurface {
            id: surface
            color: "#1a1660"

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            Image {
                anchors.fill: parent
                source: Theme.wallpaper
                sourceSize: Qt.size(surface.width, surface.height)
                fillMode: Image.PreserveAspectCrop
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0.04, 0.03, 0.16, 0.3) }
                    GradientStop { position: 0.45; color: "transparent" }
                    GradientStop { position: 1; color: Qt.rgba(0.04, 0.03, 0.16, 0.4) }
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.08
                spacing: 0

                ShadowText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (clock.date.getMonth() + 1) + "月" + clock.date.getDate() + "日 "
                        + ["日", "月", "火", "水", "木", "金", "土"][clock.date.getDay()] + "曜日"
                    font.pixelSize: Math.round(surface.height * 0.026)
                    font.weight: Font.DemiBold
                }

                // HyperOS 4 のような、縦に伸ばした大きな時計
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "H:mm")
                    color: Qt.rgba(1, 1, 1, 0.82)
                    font.family: Theme.font
                    font.pixelSize: Math.round(surface.height * 0.3)
                    font.weight: Font.DemiBold
                    font.letterSpacing: -surface.height * 0.014
                    font.features: { "tnum": 1 }
                    transform: Scale { yScale: 1.22; origin.y: 0 }
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Qt.rgba(0.27, 0.08, 0.55, 0.4)
                        shadowBlur: 1
                        shadowVerticalOffset: 6
                    }
                }
            }

            // 通知（重ねて件数だけ見せる）
            Rectangle {
                visible: Notifs.list.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: field.top
                anchors.bottomMargin: 36
                width: 540
                height: 80
                radius: 26
                color: Qt.rgba(0.98, 0.98, 0.99, 0.84)

                Rectangle {
                    z: -1
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 11
                    width: parent.width * 0.95
                    height: parent.height
                    radius: 26
                    color: Qt.rgba(0.98, 0.98, 0.99, 0.55)
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Image {
                        width: 42
                        height: 42
                        source: Notifs.list.length > 0 ? Notifs.iconFor(Notifs.list[Notifs.list.length - 1]) : ""
                        sourceSize: Qt.size(84, 84)
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: Notifs.list.length > 0 ? Notifs.list[Notifs.list.length - 1].summary : ""
                            color: Theme.ink
                            font.family: Theme.font
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            width: 440
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "通知 " + Notifs.list.length + "件"
                            color: "#6e6e76"
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                    }
                }
            }

            // パスワード欄
            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.12
                width: 340
                height: 52
                radius: 26
                color: Qt.rgba(1, 1, 1, 0.22)
                border.width: 1
                border.color: root.error.length > 0 ? Qt.rgba(1, 0.4, 0.4, 0.9) : Qt.rgba(1, 1, 1, 0.38)

                // 間違えたときに左右に揺れる
                property real shake: 0
                transform: Translate { x: field.shake }
                SequentialAnimation {
                    id: shakeAnimation
                    NumberAnimation { target: field; property: "shake"; to: -14; duration: 50 }
                    NumberAnimation { target: field; property: "shake"; to: 12; duration: 70 }
                    NumberAnimation { target: field; property: "shake"; to: -8; duration: 70 }
                    NumberAnimation { target: field; property: "shake"; to: 0; duration: 90 }
                }

                Connections {
                    target: root
                    function onErrorChanged() {
                        if (root.error.length > 0)
                            shakeAnimation.restart();
                    }
                }

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: "white"
                    font.family: Theme.font
                    font.pixelSize: 18
                    focus: true
                    enabled: !root.checking
                    onAccepted: {
                        root.submit(text);
                        text = "";
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: input.text.length === 0
                        text: root.checking ? "確認しています…" : "パスワード"
                        color: Qt.rgba(1, 1, 1, 0.75)
                        font.family: Theme.font
                        font.pixelSize: 16
                    }
                }
            }

            ShadowText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: field.bottom
                anchors.topMargin: 14
                text: root.error.length > 0 ? root.error : "パスワードを入力して Enter で解除"
                opacity: 0.9
                font.pixelSize: 13
            }
        }
    }
}
