pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Громкость выхода по умолчанию (PipeWire).
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.ready && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false

    readonly property string icon: muted || volume <= 0.001 ? "volume_off"
                                 : volume < 0.34 ? "volume_mute"
                                 : volume < 0.67 ? "volume_down" : "volume_up"

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    function setVolume(v) {
        if (!ready) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function step(d) { setVolume(volume + d); }
    function toggleMute() { if (ready) sink.audio.muted = !sink.audio.muted; }
}
