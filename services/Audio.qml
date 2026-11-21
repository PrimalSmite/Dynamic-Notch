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

    readonly property var _inputDevices: {
        const nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
        const out = [];
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n && !n.isSink && !n.isStream) out.push(n);
        }
        return out;
    }

    PwObjectTracker {
        objects: {
            const arr = [];
            if (root.sink) arr.push(root.sink);
            if (root.source) arr.push(root.source);
            const devs = root._inputDevices;
            for (let i = 0; i < devs.length; i++) arr.push(devs[i]);
            const streams = root._inputStreams;
            for (let i = 0; i < streams.length; i++) arr.push(streams[i]);
            return arr;
        }
    }

    readonly property string sinkName: {
        if (!sink) return "";
        let raw = (sink.description || sink.nickname || sink.name || "").trim();
        raw = raw.replace(/\s+(Analog|Digital)\s+Stereo.*$/i, "")
                 .replace(/\s+IEC958.*$/i, "")
                 .replace(/\s*\([^)]*Controller[^)]*\)/gi, "")
                 .trim();
        return raw || "Audio Output";
    }

    readonly property string sinkIcon: {
        const s = sinkName.toLowerCase();
        if (s.indexOf("headphone") !== -1 || s.indexOf("headset") !== -1 || s.indexOf("earbud") !== -1 || s.indexOf("buds") !== -1)
            return "headphones";
        if (s.indexOf("hdmi") !== -1 || s.indexOf("displayport") !== -1 || s.indexOf("monitor") !== -1 || s.indexOf("tv") !== -1)
            return "tv";
        return "speaker";
    }

    signal volumeStepped(real delta, int boundary)
    signal micMuteToggled(bool muted)
    signal sinkSwitched(string name, string icon)

    property bool _audioInitDone: false
    property int _lastSinkId: -1
    property bool _lastMicMuted: false

    Timer {
        interval: 1200
        running: true
        repeat: false
        onTriggered: {
            root._lastSinkId = root.sink ? root.sink.id : -1;
            root._lastMicMuted = root.micMuted;
            root._audioInitDone = true;
        }
    }

    onSinkChanged: {
        if (!_audioInitDone || !sink) return;
        if (sink.id !== _lastSinkId) {
            _lastSinkId = sink.id;
            sinkSwitched(sinkName, sinkIcon);
        }
    }

    onMicMutedChanged: {
        if (!_audioInitDone) return;
        if (micMuted !== _lastMicMuted) {
            _lastMicMuted = micMuted;
            micMuteToggled(micMuted);
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
    function step(d) {
        if (!ready || !isFinite(d)) return;
        const cur = sink.audio.muted ? 0 : sink.audio.volume;
        const next = cur + d;
        const boundary = (d > 0 && cur >= 0.995) ? 1 : (d < 0 && cur <= 0.005) ? -1 : 0;
        setVolume(next);
        volumeStepped(d, boundary);
    }
    function toggleMute() { if (ready) sink.audio.muted = !sink.audio.muted; }
    function toggleMic() {
        const targetMuted = !root.micMuted;
        let touched = false;
        const devs = root._inputDevices;
        for (let i = 0; i < devs.length; i++) {
            const n = devs[i];
            if (!n || !n.ready || !n.audio) continue;
            const props = n.properties || ({});
            const mclass = String(props["media.class"] || "");
            if (mclass !== "" && mclass.indexOf("Audio/Source") === -1) continue;
            n.audio.muted = targetMuted;
            touched = true;
        }
        if (sourceReady) {
            source.audio.muted = targetMuted;
            touched = true;
        }
        if (!touched) {
            Quickshell.execDetached(["sh", "-c", "command -v wpctl >/dev/null 2>&1 && wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"]);
        }
    }
}
