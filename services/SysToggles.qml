pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Global system mode toggles (Night Light, Keep-Awake, Game Mode) shared across
// SettingsPanel and compact Notch Live Activity wings.
Singleton {
    id: root

    property bool nightLight: false
    property int nightTemp: 4200
    property bool keepAwake: false
    property bool gameMode: false
    property bool hasHyprsunset: true
    property bool hasSystemdInhibit: true

    // Saved Hyprland option values before enabling Game Mode so disabling restores them cleanly
    property var _savedGameOpts: null

    // Sync state on startup/reload with running background processes and binary availability
    Process {
        id: syncProc
        running: true
        command: [
            "sh", "-c",
            "command -v hyprsunset >/dev/null 2>&1 && echo HS=1 || echo HS=0; " +
            "command -v systemd-inhibit >/dev/null 2>&1 && echo SI=1 || echo SI=0; " +
            "pgrep -x hyprsunset >/dev/null 2>&1 && echo NL=1 || echo NL=0"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i] === "HS=0") root.hasHyprsunset = false;
                    else if (lines[i] === "SI=0") root.hasSystemdInhibit = false;
                    else if (lines[i] === "NL=1") root.nightLight = true;
                }
            }
        }
    }

    // Debounced hyprsunset launcher to avoid Wayland gamma-control race when restarting or dragging slider
    Timer {
        id: nightApplyTimer
        interval: 120
        onTriggered: {
            if (!root.nightLight || !root.hasHyprsunset) return;
            nightRestartProc.running = false;
            nightRestartProc.command = [
                "sh", "-c",
                "pkill -x hyprsunset 2>/dev/null; i=0; while pgrep -x hyprsunset >/dev/null 2>&1 && [ $i -lt 15 ]; do sleep 0.03; i=$((i+1)); done; exec hyprsunset -t \"$1\" >/dev/null 2>&1",
                "_", String(root.nightTemp)
            ];
            nightRestartProc.running = true;
        }
    }

    Process {
        id: nightRestartProc
        onExited: (code) => {
            if (code !== 0 && root.nightLight) {
                // Only clear if hyprsunset actually failed to stay running
                nightCheckProc.running = false;
                nightCheckProc.running = true;
            }
        }
    }

    Process {
        id: nightCheckProc
        command: ["pgrep", "-x", "hyprsunset"]
        onExited: (code) => {
            if (code !== 0) root.nightLight = false;
        }
    }

    // Managed systemd-inhibit process (no /tmp PID files, clean termination on disable or shell exit)
    Process {
        id: keepAwakeProc
        command: ["systemd-inhibit", "--what=idle", "--who=DynamicNotch", "--why=KeepAwake", "sleep", "infinity"]
        onExited: {
            root.keepAwake = false;
        }
    }

    Process {
        id: gameSaveProc
        command: [
            "sh", "-c",
            "for opt in animations:enabled decoration:blur:enabled general:gaps_in general:gaps_out; do " +
            "  val=$(hyprctl getoption \"$opt\" 2>/dev/null | awk '/^(int|custom type):/{sub(/^[^:]+:[[:space:]]*/, \"\"); print; exit}'); " +
            "  printf '%s=%s\\n' \"$opt\" \"$val\"; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const saved = {};
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const idx = lines[i].indexOf("=");
                    if (idx > 0) {
                        const k = lines[i].slice(0, idx);
                        const v = lines[i].slice(idx + 1).trim();
                        if (v.length > 0) saved[k] = v;
                    }
                }
                root._savedGameOpts = saved;
                if (root.gameMode) {
                    Quickshell.execDetached([
                        "hyprctl", "--batch",
                        "keyword animations:enabled 0 ; keyword decoration:blur:enabled 0 ; keyword general:gaps_in 0 ; keyword general:gaps_out 0"
                    ]);
                }
            }
        }
    }

    signal modeToggled(string modeKey, bool enabled)
    signal screenshotTaken(string mode)

    function setNightTemp(temp) {
        nightTemp = Math.max(2500, Math.min(6500, Math.round(temp)));
        if (nightLight && hasHyprsunset) {
            nightApplyTimer.restart();
        }
    }

    function toggleNightLight() {
        if (!nightLight && !hasHyprsunset) return;
        nightLight = !nightLight;
        modeToggled("nightLight", nightLight);
        if (nightLight) {
            nightApplyTimer.restart();
        } else {
            nightApplyTimer.stop();
            nightRestartProc.running = false;
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
        }
    }

    function toggleKeepAwake() {
        if (!keepAwake && !hasSystemdInhibit) return;
        keepAwake = !keepAwake;
        modeToggled("keepAwake", keepAwake);
        if (keepAwake) {
            keepAwakeProc.running = false;
            keepAwakeProc.running = true;
        } else {
            keepAwakeProc.running = false;
        }
    }

    function toggleGameMode() {
        gameMode = !gameMode;
        modeToggled("gameMode", gameMode);
        if (gameMode) {
            gameSaveProc.running = false;
            gameSaveProc.running = true;
        } else if (_savedGameOpts && Object.keys(_savedGameOpts).length > 0) {
            const parts = [];
            for (const k in _savedGameOpts) {
                parts.push("keyword " + k + " " + _savedGameOpts[k]);
            }
            Quickshell.execDetached(["hyprctl", "--batch", parts.join(" ; ")]);
            _savedGameOpts = null;
        } else {
            Quickshell.execDetached(["hyprctl", "reload"]);
        }
    }

    Process {
        id: screenshotProc
        property string modeName: "region"
        onExited: (code) => {
            if (code === 0) {
                Clipboard.suppressCopied(1500);
                root.screenshotTaken(modeName);
            }
        }
    }

    function takeScreenshotRegion() {
        if (screenshotProc.running) return;
        Clipboard.suppressCopied(2500);
        screenshotProc.modeName = "region";
        screenshotProc.command = ["sh", "-c", "sleep 0.25 && REG=$(slurp </dev/null) && [ -n \"$REG\" ] && grim -g \"$REG\" - | wl-copy"];
        screenshotProc.running = true;
    }

    function takeScreenshotFull() {
        if (screenshotProc.running) return;
        Clipboard.suppressCopied(2500);
        screenshotProc.modeName = "full";
        screenshotProc.command = ["sh", "-c", "sleep 0.25 && grim - | wl-copy"];
        screenshotProc.running = true;
    }
}
