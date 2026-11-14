pragma Singleton
import Quickshell
import QtQuick

// Central priority aggregator for Live Activity.
// Supports unified activeItems queue:
//   - 1 active widget -> split symmetrically across left & right sides of the notch
//   - 2+ active widgets -> primary on left, secondary on right (inline) or detached ring (duo)
Singleton {
    id: root

    // ── Media pause grace window (keeps artwork visible for 15s after pause) ──
    property bool _mediaGrace: false
    readonly property bool _mediaPlaying: Media.player !== null && Media.playing

    on_MediaPlayingChanged: {
        if (_mediaPlaying) {
            mediaGraceTimer.stop();
            _mediaGrace = true;
        } else if (Media.player !== null) {
            mediaGraceTimer.restart();
        } else {
            mediaGraceTimer.stop();
            _mediaGrace = false;
        }
    }

    Connections {
        target: Media
        function onPlayerChanged() {
            if (Media.player === null) {
                mediaGraceTimer.stop();
                root._mediaGrace = false;
            }
        }
    }

    Timer {
        id: mediaGraceTimer
        interval: 15000
        repeat: false
        onTriggered: root._mediaGrace = false
    }

    // ── External IPC background task slot ──
    // { id, label, icon, progress (0..1 or <0 for indeterminate), done, ok }
    property var ipcTask: null

    Timer {
        id: ipcAutoClear
        interval: 3000
        repeat: false
        onTriggered: root.ipcTask = null
    }

    function startTask(id, label, icon, progress) {
        ipcAutoClear.stop();
        const p = (typeof progress === "number" && !isNaN(progress)) ? progress : -1;
        ipcTask = {
            id: id || "task",
            label: (label || "Task").trim(),
            icon: (icon && icon.length > 0) ? icon : "sync",
            progress: p > 1 ? 1 : p,
            done: false,
            ok: true
        };
    }

    function updateTask(id, progress, label) {
        if (!ipcTask) {
            startTask(id, label, "sync", progress);
            return;
        }
        if (id && ipcTask.id !== id) return;
        ipcAutoClear.stop();
        const p = (typeof progress === "number" && !isNaN(progress)) ? progress : ipcTask.progress;
        ipcTask = {
            id: ipcTask.id,
            label: (label && label.trim().length > 0) ? label.trim() : ipcTask.label,
            icon: ipcTask.icon,
            progress: p > 1 ? 1 : p,
            done: false,
            ok: true
        };
    }

    function finishTask(id, ok) {
        if (!ipcTask) return;
        if (id && ipcTask.id !== id) return;
        const success = (ok === undefined) ? true : !!ok;
        ipcTask = {
            id: ipcTask.id,
            label: ipcTask.label,
            icon: success ? "check_circle" : "error",
            progress: 1,
            done: true,
            ok: success
        };
        ipcAutoClear.restart();
    }

    function clearTask(id) {
        if (!ipcTask) return;
        if (id && ipcTask.id !== id) return;
        ipcAutoClear.stop();
        ipcTask = null;
    }

    // ── Unified priority queue of persistent Live Activities ──
    readonly property var activeItems: {
        if (!IslandPrefs.liveWingsEnabled) return [];
        const list = [];

        if (Recorder.recording) {
            list.push("recorder");
        }
        if (IslandPrefs.liveMediaEnabled && Media.player !== null && (Media.playing || root._mediaGrace)) {
            list.push("media");
        }
        if (Timers.running) {
            list.push("timer");
        }
        if (IslandPrefs.liveMicPrivacy && (Audio.micInUse || Audio.micMuted)) {
            list.push("mic");
        }
        if (IslandPrefs.liveThermalAlert && (SysInfo.cpuTemp >= 80 || SysInfo.highLoadAlert || SysInfo.mem >= 0.90)) {
            list.push("thermal");
        }
        if (root.ipcTask !== null) {
            list.push("ipc");
        }
        if (IslandPrefs.liveSystemModes && (SysToggles.keepAwake || SysToggles.nightLight || SysToggles.gameMode)) {
            list.push("modes");
        }
        if (IslandPrefs.liveAudioMuted && Audio.muted) {
            list.push("muted");
        }
        return list;
    }

    readonly property string primaryKind: activeItems.length > 0 ? activeItems[0] : ""
    readonly property var secondaryItems: activeItems.length > 1 ? activeItems.slice(1) : []
    readonly property bool isSplitMode: activeItems.length === 1

    // Left-click always opens the corresponding menu/panel
    function openMenu(kind, host) {
        if (!host || !kind) return;
        if (kind === "recorder") host.openPanel("recorder");
        else if (kind === "timer") host.openPanel("timer");
        else if (kind === "media") host.openPanel("media");
        else if (kind === "mic" || kind === "muted") host.openPanel("mixer");
        else if (kind === "thermal" || kind === "ipc") host.openPanel("sysmon");
        else if (kind === "modes") host.openPanel("settings");
    }
}
