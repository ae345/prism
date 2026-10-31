//@ pragma IconTheme Prism
//@ pragma UseQApplication

// Prism シェルの入口。Hyprland の起動時に `qs -p /usr/share/myos/shell` で読み込まれる。
// 画面ごとに、壁紙・ホーム画面・ステータスバー・Dock・ホームバー・Hyper Island・
// コントロールセンターを作る。ロック画面とショートカットは全画面で1つ。
import QtQuick
import Quickshell

ShellRoot {
    Component.onCompleted: Sound.play("desktop-login")

    Lock {}
    Shortcuts {}

    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    Variants {
        model: Quickshell.screens
        Home {}
    }

    Variants {
        model: Quickshell.screens
        StatusBar {}
    }

    Variants {
        model: Quickshell.screens
        Dock {}
    }

    Variants {
        model: Quickshell.screens
        HomeBar {}
    }

    Variants {
        model: Quickshell.screens
        Island {}
    }

    Variants {
        model: Quickshell.screens
        ClaudeBall {}
    }

    Variants {
        model: Quickshell.screens
        AppLibrary {}
    }

    Variants {
        model: Quickshell.screens
        ControlCenter {}
    }
}
