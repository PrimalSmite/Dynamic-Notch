pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Timer and stopwatch with display on compact notch.
Singleton {
    id: root

    property string mode: "timer"        // "timer" | "stopwatch"
    property bool running: false
    property bool paused: false

    // Timer (in seconds)
    property int totalSec: 300           // default 5 min
    property int remainSec: 300

    // Stopwatch (in seconds)
    property int elapsedSec: 0
    property var laps: []

    readonly property real progress: mode === "timer"
        ? (totalSec > 0 ? Math.max(0, Math.min(1, remainSec / totalSec)) : 0)
        : ((elapsedSec % 60) / 60)

    readonly property string display: fmt(mode === "timer" ? remainSec : elapsedSec)

    signal finished()

    function fmt(s) {
        s = Math.max(0, Math.floor(s));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        const pad = n => (n < 10 ? "0" : "") + n;
        if (h > 0) return h + ":" + pad(m) + ":" + pad(sec);
        return m + ":" + pad(sec);
    }

    function setPreset(seconds) {
        mode = "timer";
        running = false;
        paused = false;
        totalSec = Math.max(10, seconds);
        remainSec = totalSec;
    }

    function addSeconds(delta) {
        if (mode !== "timer") return;
        totalSec = Math.max(10, totalSec + delta);
        if (!running) remainSec = totalSec;
        else remainSec = Math.max(1, remainSec + delta);
    }

    function toggleStart() {
        if (!running) {
            if (mode === "timer" && remainSec <= 0) remainSec = totalSec;
            running = true;
            paused = false;
        } else {
            paused = !paused;
        }
    }

    function reset() {
        running = false;
        paused = false;
        if (mode === "timer") remainSec = totalSec;
        else { elapsedSec = 0; laps = []; }
    }

    function addLap() {
        if (mode !== "stopwatch" || !running) return;
        const next = [{ num: laps.length + 1, time: fmt(elapsedSec) }].concat(laps);
        laps = next.slice(0, 20);
    }

    Timer {
        interval: 1000
        running: root.running && !root.paused
        repeat: true
        onTriggered: {
            if (root.mode === "timer") {
                if (root.remainSec > 1) {
                    root.remainSec -= 1;
                } else {
                    root.remainSec = 0;
                    root.running = false;
                    root.paused = false;
                    root.finished();
                    Quickshell.execDetached(["notify-send", "-a", "Timer", "Time's up!", "Timer for " + root.fmt(root.totalSec) + " has finished"]);
                }
            } else {
                root.elapsedSec += 1;
            }
        }
    }
}
