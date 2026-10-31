// すべてのアプリの一覧（アプリライブラリ）。Dock の右端・ホームの「検索」・Super + Space で開く。
// 上の欄に打ち込むと絞り込み、Enter で先頭のアプリを開く。長押しでホーム画面に追加する。
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    readonly property bool open: Session.libraryOpen
    property string notice: ""

    readonly property var results: {
        const query = search.text.trim().toLowerCase();
        if (query.length === 0)
            return Apps.all;
        return Apps.all.filter(entry => {
            const text = [entry.name, entry.genericName, entry.comment, entry.id]
                .concat(entry.keywords || [])
                .join(" ")
                .toLowerCase();
            return text.indexOf(query) >= 0;
        });
    }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || backdrop.opacity > 0.01
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "myos-library"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        search.text = "";
        notice = "";
        if (open)
            search.forceActiveFocus();
    }

    function launch(entry) {
        Session.libraryOpen = false;
        Apps.launch(entry.id);
    }

    Timer {
        id: noticeTimer
        interval: 1800
        onTriggered: window.notice = ""
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.04, 0.12, 0.38)
        opacity: window.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Session.closeLibrary()
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: backdrop.opacity
        scale: window.open ? 1 : 1.06

        Behavior on scale {
            NumberAnimation { duration: Theme.springMs; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }

        // 検索欄
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            y: 70
            width: Math.min(560, parent.width - 80)
            height: 52
            radius: 26
            color: Qt.rgba(1, 1, 1, 0.24)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.4)

            Image {
                id: glass
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                source: "icons/search.svg"
                sourceSize: Qt.size(36, 36)
            }

            TextInput {
                id: search
                anchors.left: glass.right
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                selectionColor: Qt.rgba(1, 1, 1, 0.35)
                font.family: Theme.font
                font.pixelSize: 18
                clip: true
                Keys.onEscapePressed: Session.closeLibrary()
                onAccepted: {
                    if (window.results.length > 0)
                        window.launch(window.results[0]);
                }

                Text {
                    visible: search.text.length === 0 && !search.inputMethodComposing
                    text: "アプリを検索"
                    color: Qt.rgba(1, 1, 1, 0.75)
                    font: search.font
                }
            }
        }

        GridView {
            id: grid
            anchors.top: field.bottom
            anchors.topMargin: 40
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(1260, Math.floor((parent.width - 80) / cellWidth) * cellWidth)
            cellWidth: 150
            cellHeight: 140
            clip: true
            model: window.results
            boundsBehavior: Flickable.DragOverBounds

            delegate: Item {
                id: cell
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight

                Image {
                    id: icon
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 6
                    width: 80
                    height: 80
                    source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                    sourceSize: Qt.size(160, 160)
                    scale: cellMouse.pressed ? 0.88 : 1

                    Behavior on scale {
                        SpringAnimation { spring: 5; damping: 0.28 }
                    }
                }

                ShadowText {
                    anchors.top: icon.bottom
                    anchors.topMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: cell.modelData.name
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.launch(cell.modelData)
                    onPressAndHold: {
                        const added = Apps.addToHome(cell.modelData.id);
                        window.notice = added
                            ? cell.modelData.name + " をホーム画面に追加しました"
                            : "ホーム画面がいっぱいです（先にほかのアプリを外してください）";
                        noticeTimer.restart();
                    }
                }
            }
        }

        // 長押しの結果を知らせる小さな表示
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            width: noticeText.implicitWidth + 36
            height: 40
            radius: 20
            color: Qt.rgba(0, 0, 0, 0.7)
            opacity: window.notice.length > 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.fadeMs }
            }

            Text {
                id: noticeText
                anchors.centerIn: parent
                text: window.notice
                color: "white"
                font.family: Theme.font
                font.pixelSize: 14
            }
        }

        ShadowText {
            visible: window.results.length === 0
            anchors.centerIn: parent
            text: "見つかりませんでした"
            font.pixelSize: 16
        }
    }
}
