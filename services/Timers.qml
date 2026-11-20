pragma Singleton
import Quickshell
import QtQuick

// Timer and stopwatch with wall-clock accuracy and compact notch display.
Singleton {
    id: root

    property string mode: "timer"        // "timer" | "stopwatch"
    property bool running: false
    property bool paused: false

    // Timer (in seconds)
    property int totalSec: 900           // default 15 min
    property int remainSec: 900

    // Stopwatch (in seconds)
    property int elapsedSec: 0
    property var laps: []
    property int _lapCounter: 0

    // Wall-clock anchor timestamps to avoid QML Timer drift or suspend drift
    property double _endEpochMs: 0
    property double _startEpochMs: 0

    readonly property real progress: mode === "timer"
        ? (totalSec > 0 ? Math.max(0, Math.min(1, remainSec / totalSec)) : 0)
        : ((elapsedSec % 60) / 60)

    readonly property string display: fmt(mode === "timer" ? remainSec : elapsedSec)
    readonly property string compactDisplay: {
        const s = Math.max(0, Math.floor(mode === "timer" ? remainSec : elapsedSec));
        if (s < 60) return "0:" + (s < 10 ? "0" : "") + s;
        return display;
    }

    signal finished()

    function fmt(s) {
        s = Math.max(0, Math.floor(s));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        const pad = n => (n < 10 ? "0" : "") + n;
        if (h > 0) return h + ":" + pad(m) + ":" + pad(sec);
        return pad(m) + ":" + pad(sec);
    }

    function setMode(nextMode) {
        if (nextMode !== "timer" && nextMode !== "stopwatch") return;
        if (mode === nextMode) return;
        running = false;
        paused = false;
        mode = nextMode;
    }

    function setPreset(seconds) {
        mode = "timer";
        running = false;
        paused = false;
        totalSec = Math.max(60, Math.min(7200, Math.round(seconds)));
        remainSec = totalSec;
    }

    function addSeconds(delta) {
        if (mode !== "timer") return;
        totalSec = Math.max(10, Math.min(7200, totalSec + delta));
        if (!running) {
            remainSec = totalSec;
        } else {
            remainSec = Math.max(1, Math.min(7200, remainSec + delta));
            if (!paused) _endEpochMs = Date.now() + remainSec * 1000;
        }
    }

    function toggleStart() {
        if (!running) {
            if (mode === "timer") {
                if (remainSec <= 0) remainSec = totalSec;
                _endEpochMs = Date.now() + remainSec * 1000;
            } else {
                _startEpochMs = Date.now() - elapsedSec * 1000;
            }
            running = true;
            paused = false;
        } else if (!paused) {
            paused = true;
        } else {
            if (mode === "timer") {
                _endEpochMs = Date.now() + remainSec * 1000;
            } else {
                _startEpochMs = Date.now() - elapsedSec * 1000;
            }
            paused = false;
        }
    }

    function reset() {
        running = false;
        paused = false;
        if (mode === "timer") {
            remainSec = totalSec;
        } else {
            elapsedSec = 0;
            laps = [];
            _lapCounter = 0;
        }
    }

    function addLap() {
        if (mode !== "stopwatch" || !running) return;
        _lapCounter += 1;
        const next = [{ num: _lapCounter, time: fmt(elapsedSec) }].concat(laps);
        laps = next.slice(0, 20);
    }

    Timer {
        interval: 250
        running: root.running && !root.paused
        repeat: true
        onTriggered: {
            const now = Date.now();
            if (root.mode === "timer") {
                const rem = Math.ceil((root._endEpochMs - now) / 1000);
                if (rem > 0) {
                    if (root.remainSec !== rem) root.remainSec = rem;
                } else {
                    root.remainSec = 0;
                    root.running = false;
                    root.paused = false;
                    root.finished();
                    Quickshell.execDetached([
                        "sh", "-c",
                        "command -v notify-send >/dev/null 2>&1 && notify-send -a Timer \"Time's up!\" \"$1\"",
                        "_", "Timer for " + root.fmt(root.totalSec) + " has finished"
                    ]);
                }
            } else {
                const el = Math.max(0, Math.floor((now - root._startEpochMs) / 1000));
                if (root.elapsedSec !== el) root.elapsedSec = el;
            }
        }
    }
}
