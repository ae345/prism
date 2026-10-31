// Hyprland のキー操作から呼ばれるショートカット（hyprland.lua の hl.dsp.global で結びつける）
import QtQuick
import Quickshell
import Quickshell.Hyprland

Scope {
    GlobalShortcut {
        name: "controlCenter"
        description: "コントロールセンターを開く・閉じる"
        onReleased: Session.toggleControlCenter()
    }

    GlobalShortcut {
        name: "apps"
        description: "すべてのアプリを開く・閉じる"
        onReleased: Session.toggleLibrary()
    }

    GlobalShortcut {
        name: "lock"
        description: "画面をロックする"
        onReleased: Session.lock()
    }
}
