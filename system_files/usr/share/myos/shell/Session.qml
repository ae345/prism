pragma Singleton

// 画面全体の状態（コントロールセンターの開閉、集中モード、ゲームモード、ロック）と、電源まわりの操作
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool controlCenterOpen: false
    property bool libraryOpen: false
    property bool ballEnabled: true
    property bool doNotDisturb: false
    property bool gameMode: false
    property bool locked: false

    function toggleControlCenter() {
        libraryOpen = false;
        controlCenterOpen = !controlCenterOpen;
        Sound.play(controlCenterOpen ? "myos-open" : "myos-close");
    }

    function toggleLibrary() {
        controlCenterOpen = false;
        libraryOpen = !libraryOpen;
        Sound.play(libraryOpen ? "myos-open" : "myos-close");
    }

    function closeLibrary() {
        if (!libraryOpen)
            return;
        libraryOpen = false;
        Sound.play("myos-close");
    }

    function closeControlCenter() {
        if (!controlCenterOpen)
            return;
        controlCenterOpen = false;
        Sound.play("myos-close");
    }

    // ゲームモード中は通知を止める（集中モードと同じ扱い）
    function setGameMode(on) {
        gameMode = on;
        doNotDisturb = on;
    }

    function setDark(on) {
        Theme.dark = on;
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme",
            on ? "prefer-dark" : "default"]);
    }

    function lock() {
        controlCenterOpen = false;
        libraryOpen = false;
        locked = true;
    }

    function logout() {
        Quickshell.execDetached(["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""]);
    }

    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function powerOff() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    function screenshot() {
        controlCenterOpen = false;
        // パネルが閉じきってから撮る
        shotTimer.restart();
    }

    Timer {
        id: shotTimer
        interval: 450
        onTriggered: Quickshell.execDetached(["/usr/libexec/myos-screenshot"])
    }
}
