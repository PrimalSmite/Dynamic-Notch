pragma Singleton
import Quickshell
import QtQuick

// Central priority aggregator for Left and Right Live Activity wings on the compact notch.
// Left wing  — media stream, background IPC tasks, recent clipboard pulse.
// Right wing — mic privacy/mute, thermal/load alerts, active system modes, muted output, Caps Lock.
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

    // ── Priority queues ──
    readonly property var leftItems: {
        if (!IslandPrefs.liveWingsEnabled) return [];
        const list = [];

        if (IslandPrefs.liveMediaEnabled && Media.player !== null && (Media.playing || root._mediaGrace)) {
            list.push("media");
        }
        if (root.ipcTask !== null) {
            list.push("ipc");
        }
        if (IslandPrefs.liveClipboardPulse && Clipboard.recentCopy) {
            list.push("clipboard");
        }
        return list;
    }

    readonly property var rightItems: {
        if (!IslandPrefs.liveWingsEnabled) return [];
        const list = [];

        if (IslandPrefs.liveMicPrivacy && (Audio.micInUse || Audio.micMuted)) {
            list.push("mic");
        }
        if (IslandPrefs.liveThermalAlert && (SysInfo.cpuTemp >= 80 || SysInfo.highLoadAlert || SysInfo.mem >= 0.90)) {
            list.push("thermal");
        }
        if (IslandPrefs.liveSystemModes && (SysToggles.keepAwake || SysToggles.nightLight || SysToggles.gameMode)) {
            list.push("modes");
        }
        if (IslandPrefs.liveAudioMuted && Audio.muted) {
            list.push("muted");
        }
        if (IslandPrefs.liveCapsLock && Keyboard.capsLock) {
            list.push("caps");
        }
        return list;
    }
}
