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

    // ── Appearance Preferences ──
    property real uiScale: 1.15
    property int fontSize: 13
    property string fontFamily: "SF Pro Rounded"

    // ── Live Activity Wings Preferences ──
    property bool liveWingsEnabled: true
    property string liveActivityStyle: "inline" // "inline" | "duo"
    property bool liveMediaEnabled: true
    property bool liveMediaShowTitle: false
    property bool liveClipboardPulse: true
    property bool liveMicPrivacy: true
    property bool liveThermalAlert: true
    property bool liveSystemModes: true
    property bool liveAudioMuted: true
    property bool liveCapsLock: true
    property bool liveDndEnabled: true

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
                if (data.uiScale !== undefined && typeof data.uiScale === "number") root.uiScale = Math.max(0.75, Math.min(2.0, data.uiScale));
                if (data.fontSize !== undefined && typeof data.fontSize === "number") root.fontSize = Math.max(9, Math.min(20, data.fontSize));
                if (data.fontFamily !== undefined && typeof data.fontFamily === "string" && data.fontFamily.length > 0) root.fontFamily = data.fontFamily;
                if (data.liveWingsEnabled !== undefined) root.liveWingsEnabled = !!data.liveWingsEnabled;
                if (data.liveActivityStyle === "duo" || data.liveActivityStyle === "inline") root.liveActivityStyle = data.liveActivityStyle;
                if (data.liveMediaEnabled !== undefined) root.liveMediaEnabled = !!data.liveMediaEnabled;
                if (data.liveMediaShowTitle !== undefined) root.liveMediaShowTitle = !!data.liveMediaShowTitle;
                if (data.liveClipboardPulse !== undefined) root.liveClipboardPulse = !!data.liveClipboardPulse;
                if (data.liveMicPrivacy !== undefined) root.liveMicPrivacy = !!data.liveMicPrivacy;
                if (data.liveThermalAlert !== undefined) root.liveThermalAlert = !!data.liveThermalAlert;
                if (data.liveSystemModes !== undefined) root.liveSystemModes = !!data.liveSystemModes;
                if (data.liveAudioMuted !== undefined) root.liveAudioMuted = !!data.liveAudioMuted;
                if (data.liveCapsLock !== undefined) root.liveCapsLock = !!data.liveCapsLock;
                if (data.liveDndEnabled !== undefined) root.liveDndEnabled = !!data.liveDndEnabled;
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
            showOsdInGames: root.showOsdInGames,
            uiScale: root.uiScale,
            fontSize: root.fontSize,
            fontFamily: root.fontFamily,
            liveWingsEnabled: root.liveWingsEnabled,
            liveActivityStyle: root.liveActivityStyle,
            liveMediaEnabled: root.liveMediaEnabled,
            liveMediaShowTitle: root.liveMediaShowTitle,
            liveClipboardPulse: root.liveClipboardPulse,
            liveMicPrivacy: root.liveMicPrivacy,
            liveThermalAlert: root.liveThermalAlert,
            liveSystemModes: root.liveSystemModes,
            liveAudioMuted: root.liveAudioMuted,
            liveCapsLock: root.liveCapsLock,
            liveDndEnabled: root.liveDndEnabled
        };
        const json = JSON.stringify(data, null, 2);
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "sh", root.configDir, json, root.configPath]);
    }

    function setLiveActivityStyle(style) {
        if (style !== "inline" && style !== "duo") return;
        root.liveActivityStyle = style;
        save();
    }

    function setScale(s) {
        root.uiScale = Math.round(s * 100) / 100;
        save();
    }

    function setFontSize(fs) {
        root.fontSize = Math.max(9, Math.min(20, fs));
        save();
    }

    function setFontFamily(ff) {
        root.fontFamily = ff;
        save();
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

    function togglePref(key) {
        if (root[key] === undefined) return;
        root[key] = !root[key];
        save();
    }
}
