pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Default output volume and microphone input state (PipeWire).
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.ready && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool sourceReady: source !== null && source.ready && source.audio !== null
    readonly property bool micMuted: sourceReady ? source.audio.muted : false

    readonly property var _inputStreams: {
        const nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
        const out = [];
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n && n.isStream && !n.isSink) out.push(n);
        }
        return out;
    }

    // Detect active capture streams listening to an audio input (e.g. Discord, OBS, browser call),
    // excluding desktop/sink monitor capture streams such as cava or screen recorder output capture.
    readonly property bool micInUse: {
        const streams = root._inputStreams;
        for (let i = 0; i < streams.length; i++) {
            const n = streams[i];
            if (!n || !n.ready || !n.audio) continue;
            const props = n.properties || ({});
            const mclass = String(props["media.class"] || "");
            if (mclass.indexOf("Stream/Input/Audio") === -1) continue;
            if (String(props["stream.capture.sink"] || "").toLowerCase() === "true") continue;
            const app = String(props["application.name"] || props["node.name"] || n.name || "").toLowerCase();
            if (app === "cava" || app.indexOf("cava") !== -1) continue;
            return true;
        }
        return false;
    }

    readonly property string icon: muted || volume <= 0.001 ? "volume_off"
                                 : volume < 0.34 ? "volume_mute"
                                 : volume < 0.67 ? "volume_down" : "volume_up"

    PwObjectTracker {
        objects: {
            const arr = [];
            if (root.sink) arr.push(root.sink);
            if (root.source) arr.push(root.source);
            const streams = root._inputStreams;
            for (let i = 0; i < streams.length; i++) arr.push(streams[i]);
            return arr;
        }
    }

    function setVolume(v) {
        if (!ready || !isFinite(v)) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function setSink(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }
    function setSource(node) {
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }
    function step(d) { setVolume(volume + d); }
    function toggleMute() { if (ready) sink.audio.muted = !sink.audio.muted; }
    function toggleMic() {
        if (sourceReady) {
            source.audio.muted = !source.audio.muted;
        } else {
            Quickshell.execDetached(["sh", "-c", "command -v wpctl >/dev/null 2>&1 && wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"]);
        }
    }
}
