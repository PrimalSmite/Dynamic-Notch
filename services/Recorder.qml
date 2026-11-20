pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Screen recording service (gpu-screen-recorder + slurp).
Singleton {
    id: root

    property bool recording: false
    property int elapsed: 0
    readonly property string elapsedText: {
        const m = Math.floor(elapsed / 60);
        const s = elapsed % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    property string target: "screen"     // "screen" | "region"
    property int fps: 60
    property bool audioDesktop: true
    property bool audioMic: false
    property bool showCursor: true
    property string lastFile: ""
    property var recentFiles: []
    property bool available: true
    property string statusError: ""

    property string outDir: (Quickshell.env("XDG_VIDEOS_DIR") || (Quickshell.env("HOME") + "/Videos")) + "/Recordings"

    property int bitrateKbps: 30000      // 30 Mbps (maximum clarity without compression artifacts)
    property string codec: "auto"        // "auto" | "hevc" | "h264"
    property bool selectingRegion: false
    property string pendingMonitor: "screen"
    property string _pendingTarget: ""

    // Resolve XDG_VIDEOS_DIR via xdg-user-dir if available, and check gpu-screen-recorder presence
    Process {
        id: envCheckProc
        running: true
        command: ["sh", "-c", "command -v gpu-screen-recorder >/dev/null 2>&1 && echo GSR=1 || echo GSR=0; V=$(xdg-user-dir VIDEOS 2>/dev/null); [ -n \"$V\" ] && printf 'VID=%s\\n' \"$V\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i] === "GSR=0") {
                        root.available = false;
                        root.statusError = "gpu-screen-recorder not found";
                    } else if (lines[i] === "GSR=1") {
                        root.available = true;
                        root.statusError = "";
                    } else if (lines[i].indexOf("VID=") === 0) {
                        const v = lines[i].slice(4).trim();
                        if (v.length > 0) root.outDir = v + "/Recordings";
                    }
                }
                root.refreshRecent();
            }
        }
    }

    function resolveMonitor(monitorName) {
        if (monitorName && monitorName !== "screen") return monitorName;
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name)
            return Hyprland.focusedMonitor.name;
        return "screen";
    }

    // ── Pre-record countdown ──
    readonly property int countdownSec: IslandPrefs.recCountdown
    property bool counting: false
    property int countdownLeft: 0
    property int countdownTotal: 0
    property string _countdownTarget: ""

    signal countdownStarted(int total)
    signal countdownTick(int left)
    signal countdownCancelled()
    signal recordingStarted()

    function _beginCountdown(captureTarget) {
        if (!captureTarget) return;
        if (countdownSec <= 0) {
            launchRecorder(captureTarget);
            return;
        }
        _countdownTarget = captureTarget;
        countdownTotal = countdownSec;
        countdownLeft = countdownSec;
        counting = true;
        countdownStarted(countdownTotal);
        countdownTick(countdownLeft);
        countdownTimer.restart();
    }

    function _cancelCountdown() {
        if (!counting) return;
        countdownTimer.stop();
        counting = false;
        countdownLeft = 0;
        _countdownTarget = "";
        countdownCancelled();
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdownLeft = Math.max(0, root.countdownLeft - 1);
            if (root.countdownLeft <= 0) {
                countdownTimer.stop();
                const t = root._countdownTarget;
                root.counting = false;
                root._countdownTarget = "";
                root.launchRecorder(t);
            } else {
                root.countdownTick(root.countdownLeft);
            }
        }
    }

    function start(monitorName, forceTarget) {
        if (recording || counting) return;
        if (!available) {
            statusError = "gpu-screen-recorder not installed";
            return;
        }
        statusError = "";
        if (selectingRegion) {
            slurpProc.running = false;
            selectingRegion = false;
        }
        pendingMonitor = resolveMonitor(monitorName);
        const mode = forceTarget || target;

        if (mode === "region") {
            selectingRegion = true;
            slurpProc.running = false;
            slurpProc.running = true;
        } else {
            _beginCountdown(pendingMonitor);
        }
    }

    function launchRecorder(captureTarget) {
        if (!captureTarget || typeof captureTarget !== "string") return;
        const isRegion = /^\d+x\d+\+\d+\+\d+$/.test(captureTarget);
        const safeCodec = (codec === "hevc" || codec === "h264" || codec === "auto") ? codec : "auto";
        const safeFps = Math.max(15, Math.min(240, Math.round(fps)));
        const safeBitrate = Math.max(1000, Math.min(200000, Math.round(bitrateKbps)));

        _pendingTarget = captureTarget;
        mkdirProc.command = ["mkdir", "-p", outDir];
        mkdirProc.safeCodec = safeCodec;
        mkdirProc.safeFps = safeFps;
        mkdirProc.safeBitrate = safeBitrate;
        mkdirProc.isRegion = isRegion;
        mkdirProc.running = false;
        mkdirProc.running = true;
    }

    Process {
        id: mkdirProc
        property string safeCodec: "auto"
        property int safeFps: 60
        property int safeBitrate: 30000
        property bool isRegion: false
        onExited: (code) => {
            if (code !== 0) {
                root.statusError = "Cannot create recordings directory";
                return;
            }
            const ts = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
            const out = root.outDir + "/rec_" + ts + ".mp4";
            root.lastFile = out;

            const args = ["gpu-screen-recorder"];
            if (isRegion) {
                args.push("-w", "region", "-region", root._pendingTarget);
            } else {
                args.push("-w", root._pendingTarget);
            }
            args.push(
                "-f", String(safeFps),
                "-bm", "cbr",
                "-q", String(safeBitrate),
                "-cr", "full",
                "-fm", "cfr",
                "-tune", "quality",
                "-k", safeCodec,
                "-fallback-cpu-encoding", "yes",
                "-cursor", root.showCursor ? "yes" : "no"
            );
            if (root.audioDesktop) args.push("-a", "default_output");
            if (root.audioMic) args.push("-a", "default_input");
            args.push("-o", out);

            root.elapsed = 0;
            stopWatchdog.stop();
            recProc.running = false;
            recProc.command = args;
            recProc.running = true;
            root.recording = true;
            root.recordingStarted();
        }
    }

    function stop() {
        if (counting) {
            _cancelCountdown();
            return;
        }
        if (selectingRegion) {
            slurpProc.running = false;
            selectingRegion = false;
            return;
        }
        if (!recording) return;
        // Send SIGINT (2) directly to our gpu-screen-recorder Process so it finalizes the MP4 container cleanly.
        if (recProc.running) {
            recProc.signal(2);
        }
        stopWatchdog.restart();
    }

    Timer {
        id: stopWatchdog
        interval: 10000
        onTriggered: {
            if (root.recording) {
                recProc.running = false;
                root.recording = false;
                root.refreshRecent();
            }
        }
    }

    function refreshRecent() {
        listProc.running = false;
        listProc.command = ["sh", "-c", "[ -d \"$1\" ] && ls -1t \"$1\"/*.mp4 2>/dev/null | head -n 12 || true", "_", root.outDir];
        listProc.running = true;
    }

    // Select rectangular region via slurp in WxH+X+Y format required by gpu-screen-recorder.
    // Important: </dev/null is required because non-TTY stdin makes slurp wait for rectangle list from stdin and hang.
    Process {
        id: slurpProc
        command: ["sh", "-c", "command -v slurp >/dev/null 2>&1 || exit 127; sleep 0.15 && slurp -f '%Wx%H+%x+%y' </dev/null 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.selectingRegion = false;
                const reg = text.trim();
                if (/^\d+x\d+\+\d+\+\d+$/.test(reg)) {
                    const dims = reg.split("+")[0].split("x");
                    const w = parseInt(dims[0], 10) || 0;
                    const h = parseInt(dims[1], 10) || 0;
                    if (w >= 16 && h >= 16) {
                        root._beginCountdown(reg);
                    }
                }
            }
        }
        onExited: (code) => {
            root.selectingRegion = false;
            if (code === 127) {
                root.statusError = "slurp not installed";
            }
        }
    }

    Process {
        id: recProc
        onExited: (code) => {
            stopWatchdog.stop();
            const wasElapsed = root.elapsed;
            root.recording = false;
            const mbps = Math.round(root.bitrateKbps / 1000);
            if ((code === 0 || code === 130) && wasElapsed >= 1 && root.lastFile) {
                Quickshell.execDetached(["sh", "-c", "command -v notify-send >/dev/null 2>&1 && notify-send -a 'Screen Recorder' \"$1\" \"$2\"", "_", "Video saved (" + mbps + " Mbps)", root.lastFile]);
            } else if (code !== 0 && code !== 130) {
                root.statusError = "gpu-screen-recorder exited with code " + code;
                Quickshell.execDetached(["sh", "-c", "command -v notify-send >/dev/null 2>&1 && notify-send -a 'Screen Recorder' 'Recording failed' \"$1\"", "_", root.statusError]);
            }
            root.refreshRecent();
        }
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(s => s.length > 0);
                root.recentFiles = lines;
            }
        }
    }

    Timer {
        interval: 1000
        running: root.recording
        repeat: true
        onTriggered: root.elapsed += 1
    }
}
