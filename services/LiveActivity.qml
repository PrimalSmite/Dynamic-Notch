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

    // Shared thermal/load thresholds (used by both priority queue and LiveSlotContent)
    readonly property int thermalTempThreshold: 80
    readonly property int thermalCritTemp: 90
    readonly property real memAlertThreshold: 0.90
    readonly property real memCritThreshold: 0.94

    function _normProgress(progress, fallback) {
        if (typeof progress !== "number" || !isFinite(progress)) return fallback;
        return progress > 1 ? 1 : progress;
    }

    function startTask(id, label, icon, progress) {
        ipcAutoClear.stop();
        const p = _normProgress(progress, -1);
        ipcTask = {
            id: id || "task",
            label: (label || "Task").trim(),
            icon: (icon && icon.length > 0) ? icon : "sync",
            progress: p,
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
        const p = _normProgress(progress, ipcTask.progress);
        ipcTask = {
            id: ipcTask.id,
            label: (label && label.trim().length > 0) ? label.trim() : ipcTask.label,
            icon: ipcTask.icon,
            progress: p,
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
        if (Keyboard.submap !== "") {
            list.push("submap");
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
        if (IslandPrefs.liveThermalAlert && (SysInfo.cpuTemp >= root.thermalTempThreshold || SysInfo.highLoadAlert || SysInfo.mem >= root.memAlertThreshold)) {
            list.push("thermal");
        }
        if (root.ipcTask !== null) {
            list.push("ipc");
        }
        if (IslandPrefs.liveSystemModes && (SysToggles.nightLight || SysToggles.gameMode || SysToggles.keepAwake)) {
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

    // Left-click always opens the corresponding menu/panel (or resets submap)
    function openMenu(kind, host) {
        if (!kind) return;
        if (kind === "submap") { Keyboard.resetSubmap(); return; }
        if (!host) return;
        if (kind === "recorder") host.openPanel("recorder");
        else if (kind === "timer") host.openPanel("timer");
        else if (kind === "media") host.openPanel("media");
        else if (kind === "mic" || kind === "muted") host.openPanel("mixer");
        else if (kind === "thermal" || kind === "ipc") host.openPanel("sysmon");
        else if (kind === "modes") host.openPanel("settings");
    }

    // Right/Middle click quick actions directly on Live Activity wings
    function quickAction(kind, button) {
        if (!kind) return false;
        const isRight = (button === Qt.RightButton);
        const isMiddle = (button === Qt.MiddleButton);
        if (!isRight && !isMiddle) return false;

        if (kind === "submap" && isRight) {
            Keyboard.resetSubmap();
            return true;
        }
        if (kind === "media") {
            if (isRight) Media.togglePlay();
            else if (isMiddle) Media.next();
            return true;
        }
        if (kind === "recorder" && isRight) {
            Recorder.stop();
            return true;
        }
        if (kind === "timer") {
            if (isRight) Timers.toggleStart();
            else if (isMiddle) {
                if (Timers.mode === "stopwatch") Timers.addLap();
                else Timers.reset();
            }
            return true;
        }
        if (kind === "mic" && isRight) {
            Audio.toggleMic();
            return true;
        }
        if (kind === "muted" && isRight) {
            Audio.toggleMute();
            return true;
        }
        if (kind === "modes" && isRight) {
            if (SysToggles.nightLight) SysToggles.toggleNightLight();
            else if (SysToggles.gameMode) SysToggles.toggleGameMode();
            else if (SysToggles.keepAwake) SysToggles.toggleKeepAwake();
            return true;
        }
        if (kind === "ipc" && isRight) {
            clearTask();
            return true;
        }
        return false;
    }

    // Wheel scroll actions directly on Live Activity wings
    function wheelAction(kind, stepDir, shiftHeld) {
        if (!kind || !stepDir) return false;
        const dir = stepDir > 0 ? 1 : -1;
        if (kind === "media") {
            if (shiftHeld && Media.player && Media.player.canSeek) {
                Media.player.seek(dir * 5);
            } else {
                Audio.step(dir * 0.05);
            }
            return true;
        }
        if (kind === "muted") {
            Audio.step(dir * 0.05);
            return true;
        }
        if (kind === "modes" && SysToggles.nightLight) {
            SysToggles.setNightTemp(SysToggles.nightTemp + dir * 200);
            return true;
        }
        if (kind === "timer" && Timers.mode === "timer") {
            Timers.addSeconds(dir * 30);
            return true;
        }
        if (kind === "mic" && Audio.sourceReady) {
            const cur = Audio.source.audio.muted ? 0 : Audio.source.audio.volume;
            Audio.source.audio.muted = false;
            Audio.source.audio.volume = Math.max(0, Math.min(1, cur + dir * 0.05));
            return true;
        }
        return false;
    }
}
