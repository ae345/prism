pragma Singleton

// 再生中の音楽・動画（MPRIS）。再生中のものを優先し、なければ最初のプレーヤーを使う。
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) ?? (players.length > 0 ? players[0] : null)
    readonly property bool playing: player !== null && player.isPlaying
}
