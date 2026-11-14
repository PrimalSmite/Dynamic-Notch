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

    // Sync state on startup/reload with running background processes
    Process {
        id: syncProc
        running: true
        command: [
            "sh", "-c",
            "pgrep -x hyprsunset >/dev/null 2>&1 && echo NL; " +
            "if [ -f /tmp/di-keepawake.pid ] && kill -0 \"$(cat /tmp/di-keepawake.pid 2>/dev/null)\" 2>/dev/null; then echo KA; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                root.nightLight = out.indexOf("NL") !== -1;
                root.keepAwake = out.indexOf("KA") !== -1;
            }
        }
    }

    function setNightTemp(temp) {
        nightTemp = Math.max(2500, Math.min(6500, Math.round(temp)));
        if (nightLight) {
            Quickshell.execDetached(["sh", "-c", "pkill -x hyprsunset 2>/dev/null; hyprsunset -t " + nightTemp + " >/dev/null 2>&1 &"]);
        }
    }

    function toggleNightLight() {
        nightLight = !nightLight;
        if (nightLight) {
            Quickshell.execDetached(["sh", "-c", "pkill -x hyprsunset 2>/dev/null; hyprsunset -t " + nightTemp + " >/dev/null 2>&1 &"]);
        } else {
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
        }
    }

    function toggleKeepAwake() {
        keepAwake = !keepAwake;
        if (keepAwake) {
            Quickshell.execDetached(["sh", "-c", "systemd-inhibit --what=idle --who='DynamicNotch' --why='KeepAwake' sleep infinity >/dev/null 2>&1 & echo $! > /tmp/di-keepawake.pid"]);
        } else {
            Quickshell.execDetached(["sh", "-c", "[ -f /tmp/di-keepawake.pid ] && { PID=$(cat /tmp/di-keepawake.pid); pkill -P \"$PID\" 2>/dev/null; kill \"$PID\" 2>/dev/null; rm -f /tmp/di-keepawake.pid; }"]);
        }
    }

    function toggleGameMode() {
        gameMode = !gameMode;
        if (gameMode) {
            Quickshell.execDetached(["hyprctl", "--batch", "keyword animations:enabled 0 ; keyword decoration:blur:enabled 0 ; keyword general:gaps_in 0 ; keyword general:gaps_out 0"]);
        } else {
            Quickshell.execDetached(["hyprctl", "reload"]);
        }
    }
}
