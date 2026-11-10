pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// User preferences for Dynamic Notch and Dashboard with persistence.
Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/dynamic-notch"
    readonly property string configPath: configDir + "/preferences.json"

    property bool showSeconds: false
    property string compactWidget: "weather" // "weather" | "cpu" | "net" | "none"
    property bool showVolumeOsd: true
    property bool showLayoutOsd: true
    property bool autoCollapse: true
    property bool hideInGames: true
    property bool showOsdInGames: false

    Process {
        id: initDirProc
        running: true
        command: ["sh", "-c", "mkdir -p \"$1\" && if [ ! -f \"$2\" ]; then printf '%s' \"$3\" > \"$2\"; fi", "sh", root.configDir, root.configPath, "{}"]
        onExited: {
            configFile.path = root.configPath;
            configFile.reload();
        }
    }

    FileView {
        id: configFile
        path: ""
        onLoaded: {
            try {
                const txt = configFile.text();
                if (!txt || !txt.trim()) return;
                const data = JSON.parse(txt);
                if (data.showSeconds !== undefined) root.showSeconds = !!data.showSeconds;
                if (data.compactWidget !== undefined) root.compactWidget = String(data.compactWidget);
                if (data.showVolumeOsd !== undefined) root.showVolumeOsd = !!data.showVolumeOsd;
                if (data.showLayoutOsd !== undefined) root.showLayoutOsd = !!data.showLayoutOsd;
                if (data.autoCollapse !== undefined) root.autoCollapse = !!data.autoCollapse;
                if (data.hideInGames !== undefined) root.hideInGames = !!data.hideInGames;
                if (data.showOsdInGames !== undefined) root.showOsdInGames = !!data.showOsdInGames;
            } catch (e) {
                console.log("[IslandPrefs] Config load exception:", e);
            }
        }
    }

    function save() {
        const data = {
            showSeconds: root.showSeconds,
            compactWidget: root.compactWidget,
            showVolumeOsd: root.showVolumeOsd,
            showLayoutOsd: root.showLayoutOsd,
            autoCollapse: root.autoCollapse,
            hideInGames: root.hideInGames,
            showOsdInGames: root.showOsdInGames
        };
        const json = JSON.stringify(data, null, 2);
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "sh", root.configDir, json, root.configPath]);
    }

    function setCompactWidget(w) {
        root.compactWidget = w;
        save();
    }

    function toggleSeconds() {
        root.showSeconds = !root.showSeconds;
        save();
    }

    function toggleVolumeOsd() {
        root.showVolumeOsd = !root.showVolumeOsd;
        save();
    }

    function toggleLayoutOsd() {
        root.showLayoutOsd = !root.showLayoutOsd;
        save();
    }

    function toggleAutoCollapse() {
        root.autoCollapse = !root.autoCollapse;
        save();
    }

    function toggleHideInGames() {
        root.hideInGames = !root.hideInGames;
        save();
    }

    function toggleShowOsdInGames() {
        root.showOsdInGames = !root.showOsdInGames;
        save();
    }
}
