pragma Singleton

// 効果音（tools/make_sounds.py で作った WAV）を PipeWire で鳴らす
import QtQuick
import Quickshell

Singleton {
    property bool enabled: true

    function play(name) {
        if (!enabled)
            return;
        Quickshell.execDetached(["pw-play", "/usr/share/sounds/myos/stereo/" + name + ".wav"]);
    }
}
