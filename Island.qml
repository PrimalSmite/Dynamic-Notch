import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.services
import qs.components

// Dynamic Notch on each monitor.
// Modes:
//   compact   — workspace capsules (left) · centered clock · activities & layout (right)
//   osd       — floating popup on volume / layout change or new notification
//   dashboard — two-row compact dashboard (status + tray on top, dock icons on bottom)
//   panel     — dedicated panel (launcher, notifications, polkit auth, etc.) directly in notch without dashboard header
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool isFocusedMonitor: {
        const fm = Hyprland.focusedMonitor;
        if (!fm) return true;
        if (win.modelData && fm.name) return fm.name === win.modelData.name;
        return !win.monitor || win.monitor.focused;
    }

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: modelData ? modelData.height : Theme.px(1080)
    color: "transparent"

    exclusiveZone: win.isGameActive ? 0 : Theme.compactH
    WlrLayershell.namespace: "dynamic-notch"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (mode === "dashboard" || mode === "panel")
                                 ? (win.trayMenuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
                                 : WlrKeyboardFocus.None
    mask: Region {
        item: win.notchHidden ? null : ((win.mode === "dashboard" || win.mode === "panel") ? outsideCatcher : notch)
        regions: (win.mode === "compact" && !win.notchHidden && duoBubble.shown) ? [ duoBubbleMask ] : []
    }
    Region { id: duoBubbleMask; item: duoBubble.shown ? duoBubble : null }

    // Initialize HyprlandFocusGrab beforehand so initial grab is never lost
    Timer {
        interval: 80
        running: true
        onTriggered: {
            focusGrab.active = true;
            focusGrab.active = false;
        }
    }

    property var activeTrayMenu: null
    readonly property bool trayMenuOpen: activeTrayMenu !== null

    // Protect against false-positive HyprlandFocusGrab triggers during Exclusive focus handover
    property bool grabArmed: false
    Timer {
        id: grabArmTimer
        interval: 180
        onTriggered: {
            if ((win.mode === "dashboard" || win.mode === "panel") && !win.trayMenuOpen) {
                win.grabArmed = true;
                focusGrab.active = false;
                focusGrab.active = true;
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [win]
        active: (win.mode === "dashboard" || win.mode === "panel") && win.grabArmed && !win.trayMenuOpen
        onCleared: {
            if (!win.grabArmed || win.trayMenuOpen) return;
            if (win.panel === "auth") Auth.cancel();
            win.collapse();
        }
    }

    // ───────── State ─────────
    property int gameCheckTick: 0

    // Detect game activity or fullscreen mode on this monitor
    readonly property bool isGameActive: {
        void gameCheckTick;
        if (!IslandPrefs.hideInGames) return false;

        // 1. Fullscreen mode on monitor
        if (win.monitor && win.monitor.activeWorkspace && win.monitor.activeWorkspace.hasFullscreen)
            return true;
        if (win.monitor && win.monitor.focused && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.hasFullscreen)
            return true;

        // 2. Active game window (by game tag, window class, or fullscreen state)
        const top = Hyprland.activeToplevel;
        if (top) {
            const sameMon = !top.monitor || (win.monitor && top.monitor.id === win.monitor.id);
            if (sameMon) {
                const obj = top.lastIpcObject;
                if (obj) {
                    if (obj.fullscreen && obj.fullscreen !== 0) return true;
                    if (obj.fullscreenClient && obj.fullscreenClient !== 0) return true;
                    const tags = obj.tags;
                    if (Array.isArray(tags) && tags.indexOf("game") !== -1) return true;
                    const cls = (obj.class || top.class || "").toLowerCase();
                    const initCls = (obj.initialClass || "").toLowerCase();
                    if (cls.indexOf("steam_app_") === 0 || initCls.indexOf("steam_app_") === 0
                        || cls === "gamescope" || initCls === "gamescope"
                        || cls.indexOf("heroic") === 0 || cls.indexOf("lutris") === 0
                        || cls.indexOf(".exe") !== -1 || initCls.indexOf(".exe") !== -1)
                        return true;
                }
            }
        }
        return false;
    }

    // Notch is hidden when a game/fullscreen app is running and no active popups/panels exist
    readonly property bool notchHidden: isGameActive && mode === "compact"

    property bool expanded: false       // whether dashboard itself is open
    property string panel: ""           // active dedicated panel ("" — no panel)
    property string loadedPanel: ""     // preserve content during close animation
    property string osd: ""             // "", "volume", "layout", "notif"
    property string lastOsd: "volume"
    property int osdSwitchDir: 1        // 1 = roll upward, -1 = roll downward
    property bool osdAnimateSwitch: false
    property var notif: null
    readonly property string mode: panel !== "" ? "panel"
                                 : expanded ? "dashboard"
                                 : osd !== "" ? "osd"
                                 : "compact"

    readonly property var panelOrder: [
        "launcher", "notifications", "mixer", "sysmon", "recorder",
        "timer", "wallpaper", "clipboard", "notes", "settings", "power"
    ]

    readonly property var dockItems: [
        { key: "launcher",      icon: "apps" },
        { key: "notifications", icon: "notifications" },
        { key: "mixer",         icon: "volume_up" },
        { key: "sysmon",        icon: "speed" },
        { key: "recorder",      icon: "videocam" },
        { key: "timer",         icon: "timer" },
        { key: "wallpaper",     icon: "wallpaper" },
        { key: "clipboard",     icon: "content_paste" },
        { key: "notes",         icon: "edit_note" },
        { key: "settings",      icon: "settings" },
        { key: "power",         icon: "power_settings_new" }
    ]

    function armGrab() {
        grabArmed = false;
        focusGrab.active = false;
        grabArmTimer.restart();
    }

    property int panelSwitchDir: 1
    property int panelSwitchSeq: 0

    // Open dedicated panel directly in notch (calling again collapses back into notch)
    function openPanel(name) {
        osd = "";
        if (panel === name) {
            if (panel === "auth") Auth.cancel();
            collapse();
            return;
        }
        if (panel !== "" && panel !== name) {
            const oldIdx = panelOrder.indexOf(panel);
            const newIdx = panelOrder.indexOf(name);
            panelSwitchDir = (oldIdx >= 0 && newIdx >= 0 && newIdx < oldIdx) ? -1 : 1;
            panelSwitchSeq++;
        }
        panel = name;
        loadedPanel = name;
        expanded = false;
        armGrab();
        focusActivePanel();
    }

    // Return from open panel back to dashboard (via right-click or Backspace)
    function backToDashboard() {
        osd = "";
        if (panel === "auth") Auth.cancel();
        panel = "";
        expanded = true;
        armGrab();
        body.forceActiveFocus();
    }

    function closePanel() {
        backToDashboard();
    }

    function collapse() {
        if (activeTrayMenu) {
            try { activeTrayMenu.close(); } catch (e) {}
            activeTrayMenu = null;
        }
        grabArmed = false;
        grabArmTimer.stop();
        focusGrab.active = false;
        expanded = false;
        panel = "";
    }

    function toggle() {
        osd = "";
        if (mode === "dashboard" || mode === "panel") {
            if (panel === "auth") Auth.cancel();
            collapse();
        } else {
            panel = "";
            expanded = true;
            armGrab();
            body.forceActiveFocus();
        }
    }

    function cyclePanel(delta) {
        osd = "";
        expanded = false;
        const list = panelOrder;
        const cur = list.indexOf(panel);
        let next = 0;
        if (cur < 0) next = delta > 0 ? 0 : list.length - 1;
        else next = (cur + delta + list.length) % list.length;
        if (panel !== "" && panel !== list[next]) {
            panelSwitchDir = delta >= 0 ? 1 : -1;
            panelSwitchSeq++;
        }
        panel = list[next];
        loadedPanel = panel;
        armGrab();
        focusActivePanel();
    }

    function focusActivePanel() {
        if (panelLoader.item) {
            if (typeof panelLoader.item.focusInput === "function")
                panelLoader.item.focusInput();
            else if (panelLoader.item.wantsKeyboard)
                panelLoader.item.forceActiveFocus();
            else
                body.forceActiveFocus();
        } else {
            body.forceActiveFocus();
        }
    }

    function handleRightClick(key) {
        if (key === "notifications") Notifs.dnd = !Notifs.dnd;
        else if (key === "mixer") Audio.toggleMute();
        else if (key === "media") Media.togglePlay();
        else if (key === "recorder") {
            if (Recorder.recording || Recorder.counting) Recorder.stop();
            else Recorder.start((win.monitor && win.monitor.name) ? win.monitor.name : "screen");
        } else if (key === "timer") Timers.toggleStart();
        else openPanel(key);
    }

    property string lastModeKey: "nightLight"
    property bool lastModeEnabled: false
    property string lastScreenshotMode: "region"
    property string lastTrackTitle: ""
    property string lastTrackArtist: ""
    property string lastTrackArt: ""
    property string prevTrackTitle: ""
    property string prevTrackArtist: ""
    property string prevTrackArt: ""
    property bool prevTrackSkeleton: false
    property bool trackPending: false
    property int trackSwipeDir: 1
    property int trackSwipeSeq: 0

    property string lastSavedRecFile: ""
    property string lastSavedRecDur: "0:00"
    property string lastSinkName: ""
    property string lastSinkIcon: "speaker"
    property bool lastMicMutedState: false

    function isInstantKind(kind) {
        return kind === "layout" || kind === "clipboard" || kind === "caps" || kind === "dnd"
            || kind === "mode" || kind === "screenshot" || kind === "timer_done"
            || kind === "rec_countdown" || kind === "rec_start" || kind === "rec_saved"
            || kind === "mic" || kind === "sink" || kind === "submap";
    }

    function _osdPriority(kind) {
        if (kind === "rec_countdown" || kind === "rec_start") return 5;
        if (kind === "timer_done" || kind === "rec_saved" || kind === "submap") return 4;
        if (kind === "screenshot" || kind === "notif") return 3;
        if (kind === "clipboard") return 1;
        return 2;
    }

    function showOsd(kind) {
        if ((mode !== "compact" && mode !== "osd") || !armed) return;
        if (!win.isFocusedMonitor) return;
        if (isGameActive && kind !== "notif" && kind !== "volume" && kind !== "track" && !isInstantKind(kind) && !IslandPrefs.showOsdInGames) return;
        if (kind === "volume" && !IslandPrefs.showVolumeOsd) return;
        if (kind === "layout" && !IslandPrefs.showLayoutOsd) return;
        if (kind === "clipboard" && !IslandPrefs.liveClipboardPulse) return;
        if (kind === "caps" && !IslandPrefs.liveCapsLock) return;
        if (kind === "track" && !IslandPrefs.liveTrackOsd) return;
        if (kind === "mode" && !IslandPrefs.liveModeOsd) return;
        const wasOsd = (mode === "osd");
        if (wasOsd && osd !== "" && osd !== kind && _osdPriority(kind) < _osdPriority(osd)) {
            return;
        }
        if (wasOsd && lastOsd !== kind) {
            const order = ["volume", "layout", "clipboard", "caps", "dnd", "mic", "sink", "mode", "submap", "track", "screenshot", "notif", "rec_saved", "timer_done", "rec_countdown", "rec_start"];
            const oldIdx = order.indexOf(lastOsd);
            const newIdx = order.indexOf(kind);
            osdSwitchDir = (newIdx >= oldIdx) ? 1 : -1;
            osdAnimateSwitch = true;
        } else if (!wasOsd) {
            osdAnimateSwitch = false;
        }
        lastOsd = kind;
        osd = kind;
        if (kind === "rec_countdown") {
            osdTimer.stop();
            return;
        }
        osdTimer.interval = kind === "notif" ? Theme.notifMs
                          : kind === "timer_done" ? 5000
                          : kind === "rec_saved" ? 3200
                          : kind === "track" ? (win.trackPending ? 3000 : 2200)
                          : kind === "rec_start" ? 1200
                          : kind === "screenshot" ? 2600
                          : kind === "sink" ? 1400
                          : kind === "layout" ? Theme.layoutOsdMs
                          : (kind === "clipboard" || kind === "caps" || kind === "dnd" || kind === "mode" || kind === "mic" || kind === "submap") ? 1200
                          : Theme.osdMs;
        osdTimer.restart();
    }

    onPanelChanged: {
        if (panel === "") unloadTimer.restart();
        else unloadTimer.stop();
        if (panel === "notifications") Notifs.markRead();
    }

    property bool armed: false
    Timer { interval: 1500; running: true; onTriggered: win.armed = true }
    Timer { id: osdTimer; interval: Theme.osdMs; onTriggered: win.osd = "" }
    Timer { id: collapseTimer; interval: 350; onTriggered: if (win.mode === "dashboard" && !win.trayMenuOpen) win.collapse() }
    Timer { id: unloadTimer; interval: 300; onTriggered: if (win.panel === "") win.loadedPanel = "" }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!event) return;
            const ev = event.name;
            if (ev === "fullscreen" || ev === "activewindow" || ev === "activewindowv2" || ev === "workspace" || ev === "focusedmon") {
                win.gameCheckTick++;
            }
        }
    }
    Connections {
        target: Audio
        function onVolumeChanged() { win.showOsd("volume"); }
        function onMutedChanged() { win.showOsd("volume"); }
        function onVolumeStepped(delta, boundary) {
            win.showOsd("volume");
            if (boundary !== 0) notch.triggerVolOvershoot(boundary);
        }
        function onMicMuteToggled(muted) {
            if (!win.armed) return;
            win.lastMicMutedState = muted;
            win.showOsd("mic");
        }
        function onSinkSwitched(name, icon) {
            if (!win.armed) return;
            win.lastSinkName = name;
            win.lastSinkIcon = icon;
            win.showOsd("sink");
        }
    }
    Connections {
        target: Keyboard
        function onSwitched() { win.showOsd("layout"); }
        function onCapsLockChanged() { if (win.armed) win.showOsd("caps"); }
        function onSubmapChanged() {
            if (win.armed && Keyboard.submap !== "") win.showOsd("submap");
        }
    }
    Connections {
        target: Clipboard
        function onCopied() { win.showOsd("clipboard"); }
    }
    Connections {
        target: Notifs
        function onPopup(n) { win.notif = n; win.showOsd("notif"); }
        function onDndChanged() { if (win.armed) win.showOsd("dnd"); }
    }
    Connections {
        target: Media
        function onSkipRequested(dir) {
            if (!win.armed || !IslandPrefs.liveTrackOsd) return;
            win.prevTrackTitle = win.trackPending ? "" : (win.lastTrackTitle || Media.trackTitle);
            win.prevTrackArtist = win.trackPending ? "" : (win.lastTrackArtist || Media.trackArtist);
            win.prevTrackArt = win.trackPending ? "" : (win.lastTrackArt || Media.trackArtUrl);
            win.prevTrackSkeleton = win.trackPending;
            win.trackPending = true;
            win.trackSwipeDir = dir || 1;
            win.trackSwipeSeq++;
            win.showOsd("track");
            notch.triggerImpulse((dir || 1) * Theme.px(6), Theme.px(10), 0);
        }
        function onTrackChanged(title, artist, artUrl, dir) {
            if (!win.armed) return;
            const wasPending = win.trackPending;
            if (!wasPending && dir !== 0) {
                win.prevTrackTitle = win.lastTrackTitle;
                win.prevTrackArtist = win.lastTrackArtist;
                win.prevTrackArt = win.lastTrackArt;
                win.prevTrackSkeleton = false;
                win.trackSwipeDir = dir || 1;
                win.trackSwipeSeq++;
                notch.triggerImpulse((dir || 1) * Theme.px(6), Theme.px(10), 0);
            }
            win.trackPending = false;
            win.lastTrackTitle = title;
            win.lastTrackArtist = artist;
            win.lastTrackArt = artUrl;
            win.showOsd("track");
        }
    }
    Connections {
        target: Recorder
        function onCountdownStarted() {
            if (win.armed) win.showOsd("rec_countdown");
        }
        function onCountdownCancelled() {
            if (win.osd === "rec_countdown") win.osd = "";
        }
        function onRecordingStarted() {
            if (win.armed) win.showOsd("rec_start");
        }
        function onRecordingSaved(filePath, durationText) {
            if (!win.armed) return;
            win.lastSavedRecFile = filePath || "";
            win.lastSavedRecDur = durationText || "0:00";
            win.showOsd("rec_saved");
        }
    }
    Connections {
        target: SysToggles
        function onModeToggled(modeKey, enabled) {
            if (!win.armed) return;
            win.lastModeKey = modeKey;
            win.lastModeEnabled = enabled;
            win.showOsd("mode");
        }
        function onScreenshotTaken(mode) {
            if (!win.armed) return;
            win.lastScreenshotMode = mode || "region";
            win.showOsd("screenshot");
        }
    }
    Connections {
        target: Timers
        function onFinished() {
            if (win.armed) win.showOsd("timer_done");
        }
    }
    Connections {
        target: Auth
        function onRequested() {
            if (!win.isFocusedMonitor) return;
            if (win.panel !== "auth") win.openPanel("auth");
            else win.focusActivePanel();
        }
        function onFinished() {
            if (win.panel === "auth") win.collapse();
        }
    }
    // ── Lightweight album-art accent color sampler (runs once per cover change) ──
    Image {
        id: artSamplerImg
        visible: false
        width: 16
        height: 16
        source: Media.trackArtUrl
        asynchronous: true
        cache: true
        sourceSize: Qt.size(16, 16)
        onStatusChanged: {
            if (status === Image.Ready && source !== "") {
                artSamplerCanvas.requestPaint();
            } else if (status === Image.Null || source === "") {
                Media.trackAccent = Theme.mint;
            }
        }
    }
    Canvas {
        id: artSamplerCanvas
        visible: false
        width: 8
        height: 8
        onPaint: {
            const ctx = getContext("2d");
            if (!ctx || artSamplerImg.status !== Image.Ready) return;
            ctx.clearRect(0, 0, 8, 8);
            ctx.drawImage(artSamplerImg, 0, 0, 8, 8);
            const data = ctx.getImageData(0, 0, 8, 8).data;
            let bestR = 94, bestG = 234, bestB = 212, bestScore = -1;
            for (let i = 0; i < data.length; i += 4) {
                const r = data[i], g = data[i + 1], b = data[i + 2], a = data[i + 3];
                if (a < 128) continue;
                const max = Math.max(r, g, b), min = Math.min(r, g, b);
                const lum = (max + min) / 510;
                const sat = max === min ? 0 : (max - min) / (lum > 0.5 ? (510 - max - min) : (max + min));
                if (lum < 0.14 || lum > 0.90 || sat < 0.18) continue;
                const score = sat * (1.0 - Math.abs(lum - 0.55));
                if (score > bestScore) {
                    bestScore = score;
                    bestR = r; bestG = g; bestB = b;
                }
            }
            if (bestScore > 0) {
                const c = Qt.rgba(bestR / 255, bestG / 255, bestB / 255, 1.0);
                Media.trackAccent = Qt.hsla(c.hslHue, Math.max(0.58, c.hslSaturation), Math.max(0.64, Math.min(0.76, c.hslLightness)), 1.0);
            } else {
                Media.trackAccent = Theme.text;
            }
        }
    }

    Connections {
        target: IslandIpc
        function onToggleRequested() {
            if (win.mode === "dashboard" || win.mode === "panel") {
                if (win.panel === "auth") Auth.cancel();
                win.collapse();
                return;
            }
            if (!win.isFocusedMonitor) return;
            win.toggle();
        }
        function onCloseRequested() {
            if (win.panel === "auth") Auth.cancel();
            win.collapse();
        }
        function onOpenRequested(name) {
            if (win.panel === name) {
                if (win.panel === "auth") Auth.cancel();
                win.collapse();
                return;
            }
            if (!win.isFocusedMonitor) {
                if (win.mode === "dashboard" || win.mode === "panel") win.collapse();
                return;
            }
            win.openPanel(name);
        }
        function onCycleRequested(delta) {
            if (!win.isFocusedMonitor) return;
            win.cyclePanel(delta);
        }
    }

    SystemClock {
        id: clock
        precision: IslandPrefs.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    // ───────── Dimensions ─────────
    // Tight compact Notch width with equal 12px outer padding and 10px clock gaps
    readonly property real leftZoneCompactW: (leftWingItem.active ? leftWingItem.compactW + Theme.px(10) : 0) + wsItem.compactW + Theme.px(10)
    readonly property real rightCoreCompactW: liveItem.compactW + weatherItem.compactW + compactStatItem.compactW + layoutItem.compactW
    readonly property real rightZoneCompactW: (rightCoreCompactW > 0 ? (liveItem.activeCompact ? Theme.px(7) : Theme.px(10)) + rightCoreCompactW : 0) + (rightWingItem.active ? rightWingItem.compactW + Theme.px(10) : 0)
    readonly property real compactW: leftZoneCompactW + clockPill.compactW + rightZoneCompactW + Theme.px(12) * 2
    readonly property real instantOsdW: Theme.px(196)
    readonly property real trackOsdW: Theme.px(330)
    readonly property real trackOsdH: Theme.px(68)
    readonly property bool isInstantOsd: isInstantKind(win.lastOsd)
    readonly property real topRowTargetW: wsItem.dashW + divItem.dashW + clkItem.dashW + liveItem.dashW + weatherItem.dashW + mediaItem.dashW + layoutItem.dashW + trayItem.dashW
    readonly property real dashW: Math.max(Theme.px(520),
                                  Math.max(topRowTargetW, dockBar.implicitWidth) + Theme.px(36))
    readonly property real activePanelInnerW: (panelLoader.item && panelLoader.item.implicitWidth > 0)
                                              ? panelLoader.item.implicitWidth
                                              : Theme.px(600)
    readonly property real activePanelW: activePanelInnerW + 2 * Theme.pad
    readonly property real activePanelH: (panelLoader.item ? panelLoader.item.implicitHeight : Theme.px(200))
                                         + 2 * Theme.pad

    // ───────── Outside click catcher for open panel / dashboard ─────────
    MouseArea {
        id: outsideCatcher
        anchors.fill: parent
        enabled: win.mode === "dashboard" || win.mode === "panel"
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            if (win.activeTrayMenu) {
                try { win.activeTrayMenu.close(); } catch (e) {}
                win.activeTrayMenu = null;
            }
            if (win.panel === "auth") Auth.cancel();
            win.collapse();
        }
    }

    // ───────── Dynamic Notch ─────────
    Item {
        id: notch

        anchors.horizontalCenter: parent.horizontalCenter
        y: win.notchHidden ? (-bh - Theme.notchFillet - Theme.px(10)) : 0
        width: bw + 2 * Theme.notchFillet
        height: bh
        opacity: win.notchHidden ? 0 : 1
        visible: !win.notchHidden || opacity > 0.001

        readonly property bool compactHovered: notchHover.hovered && win.mode === "compact"

        property real _volStretchW: 0
        property real _volStretchH: 0
        property real _volNudgeX: 0
        function triggerImpulse(dx, stretchW, stretchH) {
            _volStretchW = stretchW || 0;
            _volStretchH = stretchH || 0;
            _volNudgeX = dx || 0;
            volOvershootReset.restart();
        }
        function triggerVolOvershoot(dir) {
            triggerImpulse(dir * Theme.px(8), Theme.px(24), -Theme.px(3));
        }
        Timer {
            id: volOvershootReset
            interval: 140
            repeat: false
            onTriggered: {
                notch._volStretchW = 0;
                notch._volStretchH = 0;
                notch._volNudgeX = 0;
            }
        }
        Behavior on _volNudgeX { Spring { epsilon: 0.1 } }

        property real bw: (win.mode === "panel" ? win.activePanelW
                        : win.mode === "dashboard" ? win.dashW
                        : win.mode === "osd" ? (win.lastOsd === "notif" ? Theme.notifW
                                              : win.lastOsd === "track" ? win.trackOsdW
                                              : win.lastOsd === "timer_done" ? Theme.px(254)
                                              : win.lastOsd === "screenshot" ? Theme.px(268)
                                              : (win.lastOsd === "clipboard" && IslandPrefs.liveClipboardPreview && Clipboard.lastKind === "url") ? Theme.px(258)
                                              : (win.lastOsd === "clipboard" && IslandPrefs.liveClipboardPreview && Clipboard.lastPreview !== "") ? Theme.px(244)
                                              : win.lastOsd === "rec_saved" ? Theme.px(264)
                                              : win.lastOsd === "sink" ? Theme.px(244)
                                              : win.isInstantOsd ? win.instantOsdW
                                              : Theme.osdW)
                        : win.compactW + (compactHovered ? Theme.hoverGrowW : 0)) + ((win.mode === "compact" || win.mode === "osd") ? _volStretchW : 0)
        property real bh: (win.mode === "panel" ? win.activePanelH
                        : win.mode === "dashboard" ? Theme.stripH
                        : win.mode === "osd" ? (win.lastOsd === "notif" ? Theme.notifH
                                              : win.lastOsd === "track" ? win.trackOsdH
                                              : win.isInstantOsd ? Theme.compactH
                                              : Theme.osdH)
                        : Theme.compactH + (compactHovered ? Theme.hoverGrowH : 0)) + ((win.mode === "compact" || win.mode === "osd") ? _volStretchH : 0)
        transform: Translate { x: (win.mode === "compact" || win.mode === "osd") ? notch._volNudgeX : 0 }
        property real rad: (win.mode === "dashboard" || win.mode === "panel") ? Theme.expandedRadius
                         : (win.mode === "osd" && win.lastOsd === "track") ? Theme.px(24)
                         : Theme.compactRadius + (compactHovered ? Theme.px(2) : 0)
        property real cw: win.compactW + (compactHovered ? Theme.hoverGrowW : 0)
        property real ch: Theme.compactH + (compactHovered ? Theme.hoverGrowH : 0)
        Behavior on bw { Spring { epsilon: 0.5 } }
        Behavior on bh { Spring { epsilon: 0.5 } }
        Behavior on rad { Spring { epsilon: 0.2 } }
        Behavior on cw { Spring { epsilon: 0.5 } }
        Behavior on ch { Spring { epsilon: 0.5 } }
        Behavior on y { Spring { epsilon: 0.5 } }
        Behavior on opacity { NumberAnimation { duration: Theme.fadeIn; easing.type: Easing.OutCubic } }

        // Prevent clicks on notch ears from passing through to outsideCatcher
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        readonly property bool _glowAllowed: IslandPrefs.liveAmbientGlow && (win.mode === "compact" || win.mode === "osd") && !win.notchHidden
        readonly property color ambientGlowColor: {
            if (!_glowAllowed) return "transparent";
            if (win.mode === "osd" && win.lastOsd === "timer_done") return Theme.orange;
            if (win.mode === "osd" && win.lastOsd === "screenshot") return Theme.mint;
            if (Timers.running && Timers.mode === "timer" && Timers.remainSec <= 10) return Theme.orange;
            if (Recorder.recording || Recorder.counting) return Theme.red;
            if (LiveActivity.activeItems.indexOf("thermal") >= 0) return Theme.red;
            if (Audio.micInUse && !Audio.micMuted) return Theme.orange;
            if (Media.playing) return Media.trackAccent;
            return "transparent";
        }
        readonly property bool _glowBreathing: _glowAllowed && (
            (win.mode === "osd" && win.lastOsd === "timer_done")
            || Recorder.recording
            || Recorder.counting
            || (Timers.running && Timers.mode === "timer" && Timers.remainSec <= 10)
        )
        property real _pulseAlpha: 0.48
        SequentialAnimation on _pulseAlpha {
            running: notch._glowBreathing
            loops: Animation.Infinite
            NumberAnimation { from: 0.22; to: 0.62; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.62; to: 0.22; duration: 900; easing.type: Easing.InOutSine }
        }

        NotchShape {
            bodyW: notch.bw
            bodyH: notch.bh
            radius: notch.rad
            fillet: Theme.notchFillet
            color: Theme.bg
            glowColor: notch.ambientGlowColor
            glowOpacity: notch.ambientGlowColor === "transparent" ? 0
                       : notch._glowBreathing ? notch._pulseAlpha
                       : (win.mode === "osd" ? 0.42 : 0.22)
        }

        HoverHandler {
            id: notchHover
            enabled: !win.notchHidden
            onHoveredChanged: {
                if (hovered) {
                    collapseTimer.stop();
                    if (win.mode === "osd" && win.osd !== "rec_countdown") osdTimer.stop();
                } else {
                    if (win.mode === "dashboard" && IslandPrefs.autoCollapse && !win.trayMenuOpen) collapseTimer.restart();
                    else if (win.mode === "osd" && win.osd !== "rec_countdown") osdTimer.restart();
                }
            }
        }

        FocusScope {
            id: body
            x: Theme.notchFillet
            width: notch.bw
            height: notch.bh
            clip: true
            focus: true

            // Global hotkeys (Esc always collapses back into small Notch)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (win.panel === "auth") Auth.cancel();
                    win.collapse();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Tab) {
                    win.cyclePanel(1);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Backtab) {
                    win.cyclePanel(-1);
                    event.accepted = true;
                    return;
                }

                const alt = (event.modifiers & Qt.AltModifier) !== 0;
                if (win.mode === "panel" && alt && (event.key === Qt.Key_Left || event.key === Qt.Key_Backspace)) {
                    win.backToDashboard();
                    event.accepted = true;
                    return;
                }

                const textFocused = panelLoader.item && panelLoader.item.wantsTextInput === true && !alt;
                if (textFocused) return;

                if (win.mode === "panel" && event.key === Qt.Key_Backspace) {
                    win.backToDashboard();
                    event.accepted = true;
                    return;
                }

                if (win.panel === "notifications") {
                    const ch = (event.text || "").toLowerCase();
                    if (event.key === Qt.Key_C || event.key === Qt.Key_X || event.key === Qt.Key_Delete
                        || event.key === 0x06d3 || event.key === 0x06de
                        || ch === "c" || ch === "с" || ch === "x" || ch === "ч") {
                        Notifs.clear();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_D || event.key === 0x06d7 || ch === "d" || ch === "в") {
                        Notifs.dnd = !Notifs.dnd;
                        event.accepted = true;
                        return;
                    }
                }

                switch (event.key) {
                case Qt.Key_1:
                case Qt.Key_Slash: win.openPanel("launcher"); event.accepted = true; break;
                case Qt.Key_2: win.openPanel("notifications"); event.accepted = true; break;
                case Qt.Key_3: win.openPanel("mixer"); event.accepted = true; break;
                case Qt.Key_4: win.openPanel("sysmon"); event.accepted = true; break;
                case Qt.Key_5: win.openPanel("recorder"); event.accepted = true; break;
                case Qt.Key_6: win.openPanel("timer"); event.accepted = true; break;
                case Qt.Key_7: win.openPanel("wallpaper"); event.accepted = true; break;
                case Qt.Key_8: win.openPanel("clipboard"); event.accepted = true; break;
                case Qt.Key_9: win.openPanel("notes"); event.accepted = true; break;
                case Qt.Key_0: win.openPanel("settings"); event.accepted = true; break;
                case Qt.Key_Minus:
                case Qt.Key_Q: win.openPanel("power"); event.accepted = true; break;
                case Qt.Key_C: win.openPanel("calendar"); event.accepted = true; break;
                case Qt.Key_W: win.openPanel("weather"); event.accepted = true; break;
                case Qt.Key_M:
                    if (win.mode === "dashboard") { win.openPanel("media"); event.accepted = true; }
                    break;
                case Qt.Key_BracketLeft:
                    wsCompact.go(wsCompact.activeId - 1);
                    event.accepted = true;
                    break;
                case Qt.Key_BracketRight:
                    wsCompact.go(wsCompact.activeId + 1);
                    event.accepted = true;
                    break;
                case Qt.Key_Space:
                    if (win.mode === "dashboard" || win.panel === "media" || win.panel === "mixer") {
                        if (Media.player) Media.togglePlay();
                        else win.openPanel("launcher");
                        event.accepted = true;
                    }
                    break;
                }
            }

            // Background: LMB — expand dashboard, RMB — back to dashboard (from panel) or launcher (from notch), MMB — pause/music, wheel — workspaces
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                property real acc: 0
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        if (Media.player && Media.player.canTogglePlaying) Media.player.togglePlaying();
                        else Audio.toggleMute();
                        return;
                    }
                    if (mouse.button === Qt.RightButton) {
                        if (win.mode === "panel") {
                            win.backToDashboard();
                        } else if (win.mode === "compact") {
                            win.openPanel("launcher");
                        } else if (win.mode === "dashboard") {
                            win.collapse();
                        } else if (win.mode === "osd") {
                            win.osd = "";
                        }
                        return;
                    }
                    if (win.mode === "osd" && (win.lastOsd === "notif" || win.lastOsd === "dnd")) win.openPanel("notifications");
                    else if (win.mode === "osd" && (win.lastOsd === "clipboard" || win.lastOsd === "screenshot")) win.openPanel("clipboard");
                    else if (win.mode === "osd" && (win.lastOsd === "caps" || win.lastOsd === "mode")) win.openPanel("settings");
                    else if (win.mode === "osd" && win.lastOsd === "track") win.openPanel("media");
                    else if (win.mode === "osd" && win.lastOsd === "timer_done") win.openPanel("timer");
                    else if (win.mode === "osd" && win.lastOsd === "rec_countdown") Recorder.stop();
                    else if (win.mode === "osd" && win.lastOsd === "rec_start") win.openPanel("recorder");
                    else if (win.mode === "osd" && win.lastOsd === "rec_saved") {
                        if (win.lastSavedRecFile !== "") Quickshell.execDetached(["xdg-open", win.lastSavedRecFile]);
                        else win.openPanel("recorder");
                        win.osd = "";
                    }
                    else if (win.mode === "osd" && (win.lastOsd === "mic" || win.lastOsd === "sink")) win.openPanel("mixer");
                    else if (win.mode === "dashboard") win.collapse();
                    else if (win.mode === "compact") win.toggle();
                }
                onWheel: w => {
                    if (win.mode === "panel") return;
                    if (win.mode === "osd" && win.lastOsd === "volume") {
                        Audio.step(w.angleDelta.y > 0 ? 0.05 : -0.05);
                        osdTimer.restart();
                        w.accepted = true;
                        return;
                    }
                    acc += w.angleDelta.y;
                    if (Math.abs(acc) < 120) return;
                    wsCompact.go(wsCompact.activeId + (acc > 0 ? -1 : 1));
                    acc = 0;
                }
            }

            // ═════════ HOME SURFACE (Compact Notch & Expanded Dashboard with shared continuous elements) ═════════
            Item {
                id: homeView
                anchors.fill: parent
                visible: opacity > 0.001
                opacity: (win.mode === "compact" || win.mode === "dashboard") && !win.notchHidden ? 1 : 0
                scale: (win.mode === "compact" || win.mode === "dashboard") ? 1.0 : 0.88
                clip: true

                readonly property bool isDash: win.mode === "dashboard"
                property real p: isDash ? 1.0 : 0.0
                property real dashAlpha: isDash ? 1.0 : 0.0
                property real compactAlpha: isDash ? 0.0 : 1.0

                Behavior on p { Spring { epsilon: 0.01 } }
                Behavior on dashAlpha {
                    NumberAnimation {
                        duration: homeView.isDash ? 110 : Theme.fadeOut
                        easing.type: homeView.isDash ? Easing.OutCubic : Easing.InQuad
                    }
                }
                Behavior on compactAlpha {
                    NumberAnimation {
                        duration: homeView.isDash ? Theme.fadeOut : Theme.fadeIn
                        easing.type: homeView.isDash ? Easing.InQuad : Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: homeView.opacity > 0 ? Theme.fadeIn : Theme.fadeOut
                        easing.type: homeView.opacity > 0 ? Easing.OutCubic : Easing.InQuad
                    }
                }
                Behavior on scale { Spring { epsilon: 0.01 } }

                // ── ROW 1: Workspaces · Clock/Calendar · Live Activities · Weather · Media · Layout · System Tray ──
                Row {
                    id: topRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: ((notch.ch - height) / 2) * (1 - homeView.p) + Theme.px(8) * homeView.p
                    height: Theme.px(38)
                    spacing: 0
                    scale: (!homeView.isDash && notch.compactHovered) ? 1.04 : 1.0

                    Behavior on scale { Spring { epsilon: 0.01 } }

                    // ── Symmetrical Left Zone (Left Live Wing + Workspaces) ──
                    Item {
                        id: leftZone
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property real dashW: wsItem.dashW + divItem.dashW
                        width: Math.max(0, win.leftZoneCompactW + (dashW - win.leftZoneCompactW) * homeView.p)
                        height: Theme.px(38)

                        // 0. Left Live Activity wing
                        LiveWing {
                            id: leftWingItem
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            side: "left"
                            host: win
                            homeProgress: homeView.p
                            compactAlpha: homeView.compactAlpha
                            notchHovered: notch.compactHovered
                        }

                        // 1. Workspaces
                        Item {
                            id: wsItem
                            anchors.verticalCenter: parent.verticalCenter
                            x: leftWingItem.active ? (leftWingItem.width + Theme.px(10) * (1 - homeView.p)) : 0
                            readonly property real compactW: wsCompact.implicitWidth
                            readonly property real dashW: wsCompact.implicitWidth + Theme.px(12)
                            width: Math.max(0, compactW + (dashW - compactW) * homeView.p)
                            height: Theme.px(38)

                            Workspaces {
                                id: wsCompact
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                monitor: win.monitor
                            }
                        }

                        // 2. Divider (between Workspaces and Clock in dashboard)
                        Item {
                            id: divItem
                            anchors.verticalCenter: parent.verticalCenter
                            x: wsItem.x + wsItem.width
                            readonly property real compactW: 0
                            readonly property real dashW: Theme.px(1) + Theme.px(12)
                            width: Math.max(0, dashW * homeView.p)
                            height: Theme.px(38)
                            opacity: homeView.dashAlpha
                            clip: true

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: Theme.px(18)
                                color: Theme.divider
                            }
                        }
                    }

                    // 3. Clock & Calendar pill (strictly centered in compact mode)
                    Item {
                        id: clkItem
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property real compactW: clockPill.compactW
                        readonly property real dashW: clockPill.dashW + Theme.px(12)
                        width: Math.max(0, compactW + (dashW - compactW) * homeView.p)
                        height: Theme.px(38)

                        Rectangle {
                            id: clockPill
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            readonly property real compactScale: Theme.px(14) / Theme.px(17)
                            readonly property real compactW: Math.round(clockText.implicitWidth * compactScale)
                            readonly property real dashW: clockText.implicitWidth + Theme.px(7) + dateText.implicitWidth + Theme.px(16)
                            width: Math.max(0, compactW + (dashW - compactW) * homeView.p)
                            height: Theme.px(32)
                            radius: Theme.px(10)
                            color: (homeView.isDash && clkMa.containsMouse) ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            scale: (homeView.isDash && clkMa.pressed) ? 0.93 : (homeView.isDash && clkMa.containsMouse ? 1.03 : 1.0)
                            clip: true
                            Behavior on scale { Spring { epsilon: 0.01 } }

                            RollingClock {
                                id: clockText
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.px(8) * homeView.p
                                anchors.verticalCenter: parent.verticalCenter
                                timeString: Qt.formatTime(clock.date, IslandPrefs.showSeconds ? "HH:mm:ss" : "HH:mm")
                                fontSize: Theme.px(17)
                                fontWeight: homeView.p > 0.5 ? Font.Bold : Font.DemiBold
                                textColor: Theme.text
                                transformOrigin: Item.Left
                                scale: clockPill.compactScale + (1.0 - clockPill.compactScale) * homeView.p
                            }

                            Text {
                                id: dateText
                                anchors.left: clockText.left
                                anchors.leftMargin: clockText.implicitWidth * clockText.scale + Theme.px(7)
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: homeView.dashAlpha
                                text: clock.date.toLocaleDateString(Qt.locale("en_US"), "ddd d MMM").replace(/\./g, "").toUpperCase()
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                                font.weight: Font.Bold
                                font.letterSpacing: Theme.px(1)
                            }

                            MouseArea {
                                id: clkMa
                                anchors.fill: parent
                                hoverEnabled: homeView.isDash
                                cursorShape: homeView.isDash ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: homeView.isDash
                                onClicked: win.openPanel("calendar")
                            }
                        }
                    }

                    // ── Symmetrical Right Zone (Core Status Items + Right Live Wing) ──
                    Item {
                        id: rightZone
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property real dashW: liveItem.dashW + weatherItem.dashW + mediaItem.dashW + layoutItem.dashW + trayItem.dashW
                        width: Math.max(0, win.rightZoneCompactW + (dashW - win.rightZoneCompactW) * homeView.p)
                        height: Theme.px(38)

                        Row {
                            id: rightCoreRow
                            x: (win.rightCoreCompactW > 0
                                ? Math.max(liveItem.activeCompact ? Theme.px(7) : Theme.px(10), parent.width - (rightWingItem.active ? rightWingItem.width + Theme.px(10) : 0) - width)
                                : 0) * (1 - homeView.p)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                    // 4. Compact DND indicator (single small icon with balanced spacing)
                    Item {
                        id: liveItem
                        anchors.verticalCenter: parent.verticalCenter
                        property bool _dndShown: Notifs.dnd
                        Timer {
                            id: dndDelayTimer
                            interval: 180
                            repeat: false
                            onTriggered: liveItem._dndShown = Notifs.dnd
                        }
                        Connections {
                            target: Notifs
                            function onDndChanged() {
                                if (Notifs.dnd) {
                                    dndDelayTimer.restart();
                                } else {
                                    dndDelayTimer.stop();
                                    liveItem._dndShown = false;
                                }
                            }
                        }
                        readonly property bool activeCompact: _dndShown && homeView.p < 0.5
                        readonly property bool activeDash: false
                        readonly property bool active: activeCompact
                        readonly property bool hasNextCompact: weatherItem.showInCompact || compactStatItem.showInCompact || layoutItem.shouldShow
                        readonly property real compactW: activeCompact ? (Theme.px(13) + (hasNextCompact ? Theme.px(5) : 0)) : 0
                        readonly property real dashW: 0
                        width: Math.max(0, compactW * (1 - homeView.p))
                        height: Theme.px(38)
                        opacity: active ? homeView.compactAlpha : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                        visible: width > 0.5 && opacity > 0.001

                        Icon {
                            x: 0
                            anchors.verticalCenter: parent.verticalCenter
                            name: "do_not_disturb_on"
                            size: Theme.px(13)
                            color: Theme.purple
                        }

                        TapHandler { onTapped: win.openPanel("notifications") }
                    }

                    // 5. Weather pill (glides between compact and dashboard)
                    Item {
                        id: weatherItem
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool showInCompact: IslandPrefs.compactWidget === "weather" && Weather.ready
                        readonly property bool showInDash: Weather.ready
                        readonly property real compactW: showInCompact ? (wthRow.implicitWidth + (layoutItem.shouldShow ? Theme.px(7) : 0)) : 0
                        readonly property real dashW: showInDash ? (wthRow.implicitWidth + Theme.px(14) + Theme.px(12)) : 0
                        width: Math.max(0, compactW + (dashW - compactW) * homeView.p)
                        height: Theme.px(38)
                        opacity: showInCompact ? 1.0 : (showInDash ? homeView.dashAlpha : 0.0)
                        clip: true

                        Rectangle {
                            id: wthPill
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: wthRow.implicitWidth + Theme.px(14) * homeView.p
                            height: Theme.px(20) + Theme.px(12) * homeView.p
                            radius: Theme.px(10)
                            color: (homeView.isDash && wthMa.containsMouse) ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            scale: (homeView.isDash && wthMa.pressed) ? 0.93 : (homeView.isDash && wthMa.containsMouse ? 1.03 : 1.0)
                            Behavior on scale { Spring { epsilon: 0.01 } }

                            Row {
                                id: wthRow
                                anchors.centerIn: parent
                                spacing: Theme.px(5)
                                scale: 0.9 + 0.1 * homeView.p
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: Weather.icon
                                    size: Theme.px(15)
                                    color: Weather.iconColor
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: isNaN(Weather.temp) ? "" : Math.round(Weather.temp) + "°"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(13)
                                    font.weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                id: wthMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) Weather.refresh();
                                    else win.openPanel("weather");
                                }
                            }
                        }
                    }

                    // 6. Compact-only stat widget (CPU or Net when chosen)
                    Item {
                        id: compactStatItem
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool showInCompact: IslandPrefs.compactWidget === "cpu" || IslandPrefs.compactWidget === "net"
                        readonly property real compactW: showInCompact ? (statRow.implicitWidth + (layoutItem.shouldShow ? Theme.px(7) : 0)) : 0
                        readonly property real dashW: 0
                        width: Math.max(0, compactW * (1 - homeView.p))
                        height: Theme.px(38)
                        opacity: showInCompact ? homeView.compactAlpha : 0
                        clip: true

                        Row {
                            id: statRow
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(3)

                            Icon {
                                visible: IslandPrefs.compactWidget === "cpu"
                                anchors.verticalCenter: parent.verticalCenter
                                name: "memory"
                                size: Theme.px(13)
                                color: Theme.text2
                            }
                            Text {
                                visible: IslandPrefs.compactWidget === "cpu"
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(SysInfo.cpu * 100) + "%" + (SysInfo.cpuTemp > 0 ? " · " + SysInfo.cpuTemp + "°" : "")
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }

                            Icon {
                                visible: IslandPrefs.compactWidget === "net"
                                anchors.verticalCenter: parent.verticalCenter
                                name: "swap_vert"
                                size: Theme.px(13)
                                color: Theme.accent
                            }
                            Text {
                                visible: IslandPrefs.compactWidget === "net"
                                anchors.verticalCenter: parent.verticalCenter
                                text: SysInfo.netDown
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }

                            TapHandler {
                                onTapped: win.openPanel("sysmon")
                            }
                        }
                    }

                    // 7. Media pill (dashboard)
                    Item {
                        id: mediaItem
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool showInDash: Media.player !== null
                        readonly property real compactW: 0
                        readonly property real dashW: showInDash ? (medPill.width + Theme.px(12)) : 0
                        width: Math.max(0, dashW * homeView.p)
                        height: Theme.px(38)
                        opacity: showInDash ? homeView.dashAlpha : 0
                        clip: true

                        Rectangle {
                            id: medPill
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: medRow.implicitWidth + Theme.px(16)
                            height: Theme.px(32)
                            radius: Theme.px(10)
                            color: medMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: Media.playing
                                ? Qt.rgba(Media.trackAccent.r, Media.trackAccent.g, Media.trackAccent.b, 0.38)
                                : Qt.rgba(1, 1, 1, 0.07)
                            Behavior on border.color { ColorAnimation { duration: 260 } }
                            scale: medMa.pressed ? 0.94 : (medMa.containsMouse ? 1.02 : 1.0)
                            Behavior on scale { Spring { epsilon: 0.01 } }

                            Row {
                                id: medRow
                                anchors.centerIn: parent
                                spacing: Theme.px(7)

                                ClippingRectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.px(22); height: width
                                    radius: Theme.px(6)
                                    color: Qt.rgba(1, 1, 1, 0.10)
                                    scale: Media.playing ? 1.0 : 0.86
                                    opacity: Media.playing ? 1.0 : 0.68
                                    Behavior on scale { Spring { epsilon: 0.01 } }
                                    Behavior on opacity { NumberAnimation { duration: 160 } }

                                    Icon {
                                        anchors.centerIn: parent
                                        name: "music_note"
                                        size: Theme.px(14)
                                        color: Theme.text2
                                        visible: !medThumb.visible
                                    }
                                    Image {
                                        id: medThumb
                                        anchors.fill: parent
                                        source: Media.trackArtUrl
                                        cache: true
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        sourceSize: Qt.size(64, 64)
                                        visible: status === Image.Ready && source !== ""
                                    }
                                }

                                Text {
                                    id: medTitleTxt
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, Theme.px(120))
                                    elide: Text.ElideRight
                                    text: Media.trackTitle !== "" ? Media.trackTitle : (Media.player ? Media.player.identity : "")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(12)
                                    font.weight: Font.Medium
                                    property real _slideY: 0
                                    transform: Translate { y: medTitleTxt._slideY }
                                    onTextChanged: {
                                        if (homeView.isDash && text !== "") medTitleRoll.restart();
                                    }
                                    ParallelAnimation {
                                        id: medTitleRoll
                                        NumberAnimation { target: medTitleTxt; property: "_slideY"; from: Theme.px(8); to: 0; duration: 180; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: medTitleTxt; property: "opacity"; from: 0.2; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                                    }
                                }

                                AudioWave {
                                    anchors.verticalCenter: parent.verticalCenter
                                    active: Media.playing && homeView.isDash
                                    color: Media.playing ? Media.trackAccent : Theme.text3
                                    Behavior on color { ColorAnimation { duration: 260 } }
                                    maxH: Theme.px(12)
                                    minH: Theme.px(3)
                                }
                            }

                            MouseArea {
                                id: medMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        Media.togglePlay();
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        Media.next();
                                    } else {
                                        win.openPanel("media");
                                    }
                                }
                                onWheel: w => {
                                    Audio.step(w.angleDelta.y > 0 ? 0.03 : -0.03);
                                }
                            }
                        }
                    }

                    // 8. Keyboard Layout pill (with mechanical vertical drum roll)
                    Item {
                        id: layoutItem
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool shouldShow: Keyboard.shortCode !== ""
                        readonly property real compactW: shouldShow ? kbNewTxt.implicitWidth : 0
                        readonly property real dashW: shouldShow ? (kbNewTxt.implicitWidth + Theme.px(12) + (SystemTray.items.values.length > 0 ? Theme.px(12) : 0)) : 0
                        width: Math.max(0, compactW + (dashW - compactW) * homeView.p)
                        height: Theme.px(38)
                        opacity: shouldShow ? 1 : 0
                        clip: true

                        Rectangle {
                            id: kbPill
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: kbNewTxt.implicitWidth + Theme.px(12) * homeView.p
                            height: Theme.px(20) + Theme.px(4) * homeView.p
                            radius: Theme.px(7)
                            clip: true
                            color: homeView.isDash ? (kbMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)) : Qt.rgba(1, 1, 1, 0.07 * homeView.p)
                            property real _popScale: 1.0
                            scale: ((homeView.isDash && kbMa.pressed) ? 0.90 : (homeView.isDash && kbMa.containsMouse ? 1.05 : 1.0)) * _popScale
                            Behavior on scale { Spring { epsilon: 0.01 } }

                            property string _curCode: Keyboard.shortCode
                            property string _prevCode: Keyboard.shortCode
                            property real _oldY: 0
                            property real _newY: 0

                            Connections {
                                target: Keyboard
                                function onShortCodeChanged() {
                                    const next = Keyboard.shortCode;
                                    if (!next || next === kbPill._curCode) return;
                                    kbPill._prevCode = kbPill._curCode;
                                    kbPill._curCode = next;
                                    kbRollAnim.stop();
                                    const dir = (next === "RU") ? -1 : 1;
                                    const dist = Theme.px(13);
                                    kbPill._oldY = 0;
                                    kbOldTxt.opacity = 1;
                                    kbPill._newY = dir * dist;
                                    kbNewTxt.opacity = 0;
                                    kbRollAnim.outY = -dir * dist;
                                    kbRollAnim.restart();
                                    kbPopAnim.restart();
                                }
                            }

                            SpringAnimation {
                                id: kbPopAnim
                                target: kbPill
                                property: "_popScale"
                                from: 0.86
                                to: 1.0
                                spring: Theme.springK
                                damping: Theme.springDamp
                                epsilon: 0.01
                            }

                            ParallelAnimation {
                                id: kbRollAnim
                                property real outY: -Theme.px(13)
                                NumberAnimation { target: kbPill; property: "_oldY"; to: kbRollAnim.outY; duration: 165; easing.type: Easing.OutCubic }
                                NumberAnimation { target: kbOldTxt; property: "opacity"; to: 0; duration: 140; easing.type: Easing.OutCubic }
                                NumberAnimation { target: kbPill; property: "_newY"; to: 0; duration: 185; easing.type: Easing.OutCubic }
                                NumberAnimation { target: kbNewTxt; property: "opacity"; to: 1; duration: 170; easing.type: Easing.OutCubic }
                            }

                            Text {
                                id: kbOldTxt
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: kbPill._oldY
                                text: kbPill._prevCode
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.Bold
                                opacity: 0
                                visible: opacity > 0.01
                            }
                            Text {
                                id: kbNewTxt
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: kbPill._newY
                                text: kbPill._curCode
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                id: kbMa
                                anchors.fill: parent
                                anchors.margins: homeView.isDash ? 0 : -Theme.px(5)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Keyboard.next()
                            }
                        }
                    }

                    // 9. System Tray (with separator)
                    Item {
                        id: trayItem
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool showInDash: SystemTray.items.values.length > 0
                        readonly property real compactW: 0
                        readonly property real dashW: showInDash ? trayInner.implicitWidth : 0
                        width: Math.max(0, dashW * homeView.p)
                        height: Theme.px(38)
                        opacity: showInDash ? homeView.dashAlpha : 0
                        clip: true

                        Row {
                            id: trayInner
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(12)

                            StripDivider {}

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.px(6)

                                Repeater {
                                    model: SystemTray.items

                                    Rectangle {
                                        id: trayBtn
                                        required property var modelData
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Theme.px(26)
                                        height: width
                                        radius: Theme.px(7)
                                        color: trayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                                        scale: trayMa.pressed ? 0.86 : trayMa.containsMouse ? 1.1 : 1.0
                                        Behavior on scale { Spring { epsilon: 0.01 } }

                                        QsMenuAnchor {
                                            id: trayMenu
                                            menu: (trayBtn.modelData && trayBtn.modelData.hasMenu) ? trayBtn.modelData.menu : null
                                            anchor.item: trayBtn
                                            anchor.edges: Edges.Bottom
                                            anchor.gravity: Edges.Bottom
                                            onOpened: {
                                                win.activeTrayMenu = trayMenu;
                                            }
                                            onClosed: {
                                                if (win.activeTrayMenu === trayMenu) {
                                                    win.activeTrayMenu = null;
                                                    win.armGrab();
                                                }
                                            }
                                        }

                                        IconImage {
                                            anchors.centerIn: parent
                                            implicitSize: Theme.px(17)
                                            source: {
                                                const ic = (trayBtn.modelData && trayBtn.modelData.icon) ? trayBtn.modelData.icon : "";
                                                if (!ic) return Quickshell.iconPath("application-x-executable");
                                                if (ic.indexOf("?path=") >= 0 || ic.indexOf("/") >= 0 || ic.indexOf("image://") === 0) return ic;
                                                return Quickshell.iconPath(ic, "application-x-executable");
                                            }
                                        }

                                        MouseArea {
                                            id: trayMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: mouse => {
                                                const it = trayBtn.modelData;
                                                if (!it) return;
                                                const pt = trayBtn.mapToItem(null, trayBtn.width / 2, trayBtn.height);
                                                if (mouse.button === Qt.RightButton) {
                                                    if (it.hasMenu) {
                                                        win.activeTrayMenu = trayMenu;
                                                        focusGrab.active = false;
                                                        if (it.menu) {
                                                            trayMenu.anchor.updateAnchor();
                                                            trayMenu.open();
                                                        } else {
                                                            it.display(win, Math.round(pt.x), Math.round(pt.y));
                                                        }
                                                    } else {
                                                        it.secondaryActivate();
                                                    }
                                                } else if (mouse.button === Qt.MiddleButton) {
                                                    it.secondaryActivate();
                                                } else {
                                                    if (it.onlyMenu && it.hasMenu) {
                                                        win.activeTrayMenu = trayMenu;
                                                        focusGrab.active = false;
                                                        if (it.menu) {
                                                            trayMenu.anchor.updateAnchor();
                                                            trayMenu.open();
                                                        } else {
                                                            it.display(win, Math.round(pt.x), Math.round(pt.y));
                                                        }
                                                    } else {
                                                        it.activate();
                                                    }
                                                }
                                            }
                                            onWheel: w => {
                                                if (trayBtn.modelData)
                                                    trayBtn.modelData.scroll(w.angleDelta.y, false);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                        }

                        // 10. Right Live Activity wing (pinned to right edge of notch)
                        LiveWing {
                            id: rightWingItem
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            side: "right"
                            host: win
                            homeProgress: homeView.p
                            compactAlpha: homeView.compactAlpha
                            notchHovered: notch.compactHovered
                        }
                    }
                }

                // ── ROW 2: Clean dock icons capsule ──
                Rectangle {
                    id: dockBar
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Theme.px(52) - Theme.px(4) * (1 - homeView.p)
                    implicitWidth: dockInner.implicitWidth + Theme.px(14)
                    width: implicitWidth
                    height: Theme.px(36)
                    radius: Theme.px(13)
                    color: Qt.rgba(1, 1, 1, 0.06)
                    transformOrigin: Item.Top
                    opacity: Math.min(1, Math.max(0, homeView.p * 4.0))
                    scale: 0.96 + 0.04 * homeView.p
                    visible: opacity > 0.001

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        property real wAcc: 0
                        onWheel: w => {
                            wAcc += w.angleDelta.y;
                            if (Math.abs(wAcc) < 120) return;
                            win.cyclePanel(wAcc > 0 ? -1 : 1);
                            wAcc = 0;
                        }
                    }

                    Row {
                        id: dockInner
                        anchors.centerIn: parent
                        spacing: Theme.px(3)

                        Repeater {
                            model: win.dockItems
                            StripButton {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                icon: modelData.key === "notifications" && Notifs.dnd ? "notifications_off"
                                    : modelData.key === "mixer" ? Audio.icon
                                    : modelData.icon
                                active: win.panel === modelData.key
                                badge: (modelData.key === "notifications" && Notifs.unread > 0 && !Notifs.dnd)
                                tint: modelData.key === "recorder" && Recorder.recording ? Theme.red
                                    : modelData.key === "timer" && Timers.running ? Theme.orange
                                    : modelData.key === "mixer" && Audio.muted ? Theme.red
                                    : modelData.key === "notifications" && Notifs.dnd ? Theme.purple
                                    : Theme.text
                                onClicked: win.openPanel(modelData.key)
                                onRightClicked: win.handleRightClick(modelData.key)
                            }
                        }
                    }
                }
            }

            // ═════════ OSD ═════════
            MorphView {
                id: osdView
                shown: win.mode === "osd"
                hiddenScale: 0.86
                hiddenY: -Theme.px(8)
                transformOrigin: Item.Top
                width: win.lastOsd === "notif" ? Theme.notifW
                     : win.lastOsd === "track" ? win.trackOsdW
                     : win.lastOsd === "timer_done" ? Theme.px(254)
                     : win.lastOsd === "screenshot" ? Theme.px(268)
                     : (win.lastOsd === "clipboard" && IslandPrefs.liveClipboardPreview && Clipboard.lastKind === "url") ? Theme.px(258)
                     : (win.lastOsd === "clipboard" && IslandPrefs.liveClipboardPreview && Clipboard.lastPreview !== "") ? Theme.px(244)
                     : win.lastOsd === "rec_saved" ? Theme.px(264)
                     : win.lastOsd === "sink" ? Theme.px(244)
                     : win.isInstantOsd ? win.instantOsdW
                     : Theme.osdW
                height: win.lastOsd === "notif" ? Theme.notifH
                      : win.lastOsd === "track" ? win.trackOsdH
                      : win.isInstantOsd ? Theme.compactH
                      : Theme.osdH
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                component OsdSlot: Item {
                    id: slotRoot
                    property string kind: ""
                    readonly property bool active: win.lastOsd === kind
                    property real slideY: 0

                    anchors.fill: parent
                    visible: active || opacity > 0.001
                    opacity: active ? 1 : 0
                    scale: active ? 1.0 : 0.92
                    transform: Translate { y: slotRoot.slideY }

                    onActiveChanged: {
                        slotAnim.stop();
                        if (!win.osdAnimateSwitch) {
                            slideY = 0;
                            opacity = active ? 1 : 0;
                            scale = active ? 1.0 : 0.92;
                            return;
                        }
                        const d = win.osdSwitchDir;
                        const dist = Theme.px(14);
                        if (active) {
                            slideY = d * dist;
                            opacity = 0;
                            scale = 0.92;
                            slotAnim.toY = 0;
                            slotAnim.toOpacity = 1;
                            slotAnim.toScale = 1.0;
                        } else {
                            slideY = 0;
                            opacity = 1;
                            scale = 1.0;
                            slotAnim.toY = -d * dist;
                            slotAnim.toOpacity = 0;
                            slotAnim.toScale = 0.92;
                        }
                        slotAnim.restart();
                    }

                    ParallelAnimation {
                        id: slotAnim
                        property real toY: 0
                        property real toOpacity: 1
                        property real toScale: 1
                        NumberAnimation { target: slotRoot; property: "slideY"; to: slotAnim.toY; duration: 170; easing.type: Easing.OutCubic }
                        NumberAnimation { target: slotRoot; property: "opacity"; to: slotAnim.toOpacity; duration: 160; easing.type: Easing.OutCubic }
                        NumberAnimation { target: slotRoot; property: "scale"; to: slotAnim.toScale; duration: 170; easing.type: Easing.OutCubic }
                    }
                }

                component RollingLabel: Item {
                    id: rl
                    property string text: ""
                    property color color: Theme.text
                    property int pixelSize: Theme.px(13)
                    property int fontWeight: Font.DemiBold
                    property real maxWidth: Theme.px(200)
                    property bool slotActive: false
                    // Static text/prefix that should enter top-to-bottom (-1); everything else enters bottom-to-top (+1)
                    property string topEnterText: ""
                    property string topEnterPrefix: ""

                    property string _cur: text
                    property string _prev: text
                    property real _oldY: 0
                    property real _newY: 0

                    clip: true
                    height: Theme.compactH
                    width: Math.min(newTxt.implicitWidth, maxWidth)
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    onTextChanged: {
                        if (text === _cur) return;
                        _prev = _cur;
                        _cur = text;
                        rollAnim.stop();
                        if (!slotActive || win.mode !== "osd") {
                            _oldY = 0;
                            _newY = 0;
                            oldTxt.opacity = 0;
                            newTxt.opacity = 1;
                            return;
                        }
                        const isTop = (topEnterText !== "" && text === topEnterText)
                                   || (topEnterPrefix !== "" && text.indexOf(topEnterPrefix) === 0);
                        const dir = isTop ? -1 : 1;
                        const dist = Theme.px(18);
                        _oldY = 0;
                        oldTxt.opacity = 1;
                        _newY = dir * dist;
                        newTxt.opacity = 0;
                        rollAnim.outY = -dir * dist;
                        rollAnim.restart();
                    }

                    Text {
                        id: oldTxt
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: rl._oldY
                        width: Math.min(implicitWidth, rl.maxWidth)
                        elide: Text.ElideRight
                        text: rl._prev
                        color: rl.color
                        font.family: Theme.fontFamily
                        font.pixelSize: rl.pixelSize
                        font.weight: rl.fontWeight
                        opacity: 0
                        visible: opacity > 0.01
                    }

                    Text {
                        id: newTxt
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: rl._newY
                        width: Math.min(implicitWidth, rl.maxWidth)
                        elide: Text.ElideRight
                        text: rl._cur
                        color: rl.color
                        font.family: Theme.fontFamily
                        font.pixelSize: rl.pixelSize
                        font.weight: rl.fontWeight
                        opacity: 1
                    }

                    ParallelAnimation {
                        id: rollAnim
                        property real outY: -Theme.px(18)
                        NumberAnimation { target: rl; property: "_oldY"; to: rollAnim.outY; duration: 160; easing.type: Easing.OutCubic }
                        NumberAnimation { target: oldTxt; property: "opacity"; to: 0; duration: 140; easing.type: Easing.OutCubic }
                        NumberAnimation { target: rl; property: "_newY"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                        NumberAnimation { target: newTxt; property: "opacity"; to: 1; duration: 170; easing.type: Easing.OutCubic }
                    }
                }

                // volume
                OsdSlot {
                    id: volSlot
                    kind: "volume"

                    Icon {
                        id: osdVolIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.px(18)
                        anchors.verticalCenter: parent.verticalCenter
                        name: Audio.icon
                        size: Theme.px(18)
                        color: Audio.muted ? Theme.red : Theme.text
                        onNameChanged: if (volSlot.active && win.mode === "osd") volIconPop.restart()
                        SpringAnimation {
                            id: volIconPop
                            target: osdVolIcon
                            property: "scale"
                            from: 0.76
                            to: 1.0
                            spring: Theme.springK
                            damping: Theme.springDamp
                            epsilon: 0.01
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: Theme.px(-6)
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                mouse.accepted = true;
                                if (mouse.button === Qt.RightButton) Audio.cycleSink();
                                else Audio.toggleMute();
                                osdTimer.restart();
                            }
                        }
                    }
                    Bar {
                        id: osdVolBar
                        anchors.left: osdVolIcon.right
                        anchors.right: osdVolText.left
                        anchors.leftMargin: Theme.px(12)
                        anchors.rightMargin: Theme.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        height: Theme.px(6)
                        value: Audio.muted ? 0 : Audio.volume
                        tint: Theme.text

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: Theme.px(-8)
                            cursorShape: Qt.PointingHandCursor
                            onPressed: m => {
                                Audio.setVolume(m.x / parent.width);
                                osdTimer.restart();
                            }
                            onPositionChanged: m => {
                                if (pressed) {
                                    Audio.setVolume(m.x / parent.width);
                                    osdTimer.restart();
                                }
                            }
                            onWheel: w => {
                                Audio.step(w.angleDelta.y > 0 ? 0.05 : -0.05);
                                osdTimer.restart();
                            }
                        }
                    }
                    Item {
                        id: osdVolText
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.px(18)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(32)
                        height: Theme.px(20)

                        RollingClock {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            timeString: Audio.muted ? "off" : String(Math.round(Audio.volume * 100))
                            fontSize: Theme.px(13)
                            fontWeight: Font.DemiBold
                            textColor: Audio.muted ? Theme.red : Theme.text2
                        }
                    }
                }

                // layout — compact popup sized to the notch
                OsdSlot {
                    id: layoutSlot
                    kind: "layout"

                    Row {
                        id: layoutOsdRow
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "language"
                            size: Theme.px(15)
                            color: Theme.blue
                        }
                        RollingLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Keyboard.shortCode
                            color: Theme.text
                            pixelSize: Theme.px(13)
                            fontWeight: Font.Bold
                            maxWidth: Theme.px(36)
                            slotActive: layoutSlot.active
                            topEnterText: "RU"
                        }
                        RollingLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Keyboard.layout.replace(/\s*\([^)]*\)/g, "").trim()
                            color: Theme.text2
                            pixelSize: Theme.px(12)
                            fontWeight: Font.Medium
                            maxWidth: Theme.px(110)
                            slotActive: layoutSlot.active
                            topEnterPrefix: "Russian"
                        }
                    }
                }

                // clipboard — smart preview (color swatch, URL domain, image, or text)
                OsdSlot {
                    id: clipboardSlot
                    kind: "clipboard"

                    Row {
                        id: clipboardOsdRow
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Rectangle {
                            visible: IslandPrefs.liveClipboardPreview && Clipboard.lastKind === "color" && Clipboard.lastColorHex !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(14)
                            height: width
                            radius: width / 2
                            color: Clipboard.lastColorHex || "transparent"
                            border.width: 1.5
                            border.color: Qt.rgba(1, 1, 1, 0.55)
                        }
                        Icon {
                            visible: !IslandPrefs.liveClipboardPreview || Clipboard.lastKind !== "color"
                            anchors.verticalCenter: parent.verticalCenter
                            name: !IslandPrefs.liveClipboardPreview ? "content_paste"
                                : Clipboard.lastKind === "url" ? "link"
                                : Clipboard.lastKind === "image" ? "image"
                                : "content_paste"
                            size: Theme.px(15)
                            color: (IslandPrefs.liveClipboardPreview && Clipboard.lastKind === "url") ? Theme.blue : Theme.mint
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, (IslandPrefs.liveClipboardPreview && Clipboard.lastKind === "url") ? Theme.px(140) : Theme.px(185))
                            elide: Text.ElideRight
                            text: !IslandPrefs.liveClipboardPreview ? "Copied"
                                : Clipboard.lastKind === "image" ? "Image Copied"
                                : Clipboard.lastPreview !== "" ? ("Copied · " + Clipboard.lastPreview)
                                : "Copied"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                        }
                        Rectangle {
                            visible: IslandPrefs.liveClipboardPreview && Clipboard.lastKind === "url"
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.px(22)
                            width: clipOpenLbl.implicitWidth + Theme.px(14)
                            radius: height / 2
                            color: clipOpenMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09)
                            scale: clipOpenMa.pressed ? 0.90 : 1.0
                            Behavior on scale { Spring { epsilon: 0.01 } }

                            Text {
                                id: clipOpenLbl
                                anchors.centerIn: parent
                                text: "Open"
                                color: Theme.blue
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                id: clipOpenMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    Quickshell.execDetached(["sh", "-c", "wl-paste 2>/dev/null | head -n 1 | xargs -r xdg-open"]);
                                    win.osd = "";
                                }
                            }
                        }
                    }
                }

                // dnd — compact popup sized to the notch
                OsdSlot {
                    id: dndSlot
                    kind: "dnd"

                    Row {
                        id: dndOsdRow
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Icon {
                            id: dndIcon
                            anchors.verticalCenter: parent.verticalCenter
                            name: Notifs.dnd ? "notifications_off" : "notifications_active"
                            size: Theme.px(15)
                            color: Notifs.dnd ? Theme.purple : Theme.mint

                            Connections {
                                target: Notifs
                                function onDndChanged() {
                                    if (dndSlot.active && win.mode === "osd") dndIconPop.restart();
                                }
                            }
                            SpringAnimation {
                                id: dndIconPop
                                target: dndIcon
                                property: "scale"
                                from: 0.72
                                to: 1.0
                                spring: Theme.springK
                                damping: Theme.springDamp
                                epsilon: 0.01
                            }
                        }
                        RollingLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Notifs.dnd ? "Do Not Disturb" : "Notifications On"
                            color: Theme.text
                            pixelSize: Theme.px(13)
                            fontWeight: Font.DemiBold
                            slotActive: dndSlot.active
                            topEnterText: "Do Not Disturb"
                        }
                    }
                }

                // caps — compact popup sized to the notch
                OsdSlot {
                    id: capsSlot
                    kind: "caps"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Icon {
                            id: capsIcon
                            anchors.verticalCenter: parent.verticalCenter
                            name: "keyboard_capslock"
                            size: Theme.px(15)
                            color: Keyboard.capsLock ? Theme.warn : Theme.text2

                            Connections {
                                target: Keyboard
                                function onCapsLockChanged() {
                                    if (capsSlot.active && win.mode === "osd") capsIconPop.restart();
                                }
                            }
                            SpringAnimation {
                                id: capsIconPop
                                target: capsIcon
                                property: "scale"
                                from: 0.72
                                to: 1.0
                                spring: Theme.springK
                                damping: Theme.springDamp
                                epsilon: 0.01
                            }
                        }
                        RollingLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Keyboard.capsLock ? "Caps Lock ON" : "Caps Lock OFF"
                            color: Theme.text
                            pixelSize: Theme.px(13)
                            fontWeight: Font.DemiBold
                            slotActive: capsSlot.active
                            topEnterText: "Caps Lock ON"
                        }
                    }
                }

                // mode — compact popup for Night Light / Keep Awake / Game Mode
                OsdSlot {
                    id: modeSlot
                    kind: "mode"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        readonly property string modeIcon: win.lastModeKey === "nightLight" ? "bedtime"
                                                         : win.lastModeKey === "keepAwake" ? "coffee"
                                                         : "sports_esports"
                        readonly property color modeColor: win.lastModeKey === "nightLight" ? Theme.orange
                                                         : win.lastModeKey === "keepAwake" ? Theme.yellow
                                                         : Theme.teal
                        readonly property string modeName: win.lastModeKey === "nightLight" ? "Night Light"
                                                         : win.lastModeKey === "keepAwake" ? "Keep Awake"
                                                         : "Game Mode"

                        Icon {
                            id: modeIconItem
                            anchors.verticalCenter: parent.verticalCenter
                            name: parent.modeIcon
                            size: Theme.px(15)
                            color: win.lastModeEnabled ? parent.modeColor : Theme.text2

                            Connections {
                                target: SysToggles
                                function onModeToggled() {
                                    if (modeSlot.active && win.mode === "osd") modeIconPop.restart();
                                }
                            }
                            SpringAnimation {
                                id: modeIconPop
                                target: modeIconItem
                                property: "scale"
                                from: 0.72
                                to: 1.0
                                spring: Theme.springK
                                damping: Theme.springDamp
                                epsilon: 0.01
                            }
                        }
                        RollingLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modeName + (win.lastModeEnabled ? " ON" : " OFF")
                            color: Theme.text
                            pixelSize: Theme.px(13)
                            fontWeight: Font.DemiBold
                            slotActive: modeSlot.active
                            topEnterText: parent.modeName + " ON"
                        }
                    }
                }

                // screenshot — interactive popup when grim/slurp copies screenshot
                OsdSlot {
                    id: screenshotSlot
                    kind: "screenshot"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "photo_camera"
                            size: Theme.px(15)
                            color: Theme.mint
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.lastScreenshotMode === "full" ? "Screen" : "Region"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.px(22)
                            width: shotSaveLbl.implicitWidth + Theme.px(12)
                            radius: height / 2
                            color: shotSaveMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09)
                            scale: shotSaveMa.pressed ? 0.90 : 1.0
                            Behavior on scale { Spring { epsilon: 0.01 } }

                            Text {
                                id: shotSaveLbl
                                anchors.centerIn: parent
                                text: "Save"
                                color: Theme.mint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                id: shotSaveMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    Quickshell.execDetached(["sh", "-c", "DIR=\"$(xdg-user-dir PICTURES 2>/dev/null || echo \"$HOME/Pictures\")/Screenshots\"; mkdir -p \"$DIR\" && wl-paste -t image/png > \"$DIR/shot_$(date +%Y-%m-%d_%H-%M-%S).png\""]);
                                    win.osd = "";
                                }
                            }
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.px(22)
                            width: shotEditLbl.implicitWidth + Theme.px(12)
                            radius: height / 2
                            color: shotEditMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09)
                            scale: shotEditMa.pressed ? 0.90 : 1.0
                            Behavior on scale { Spring { epsilon: 0.01 } }

                            Text {
                                id: shotEditLbl
                                anchors.centerIn: parent
                                text: "Edit"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                id: shotEditMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    Quickshell.execDetached(["sh", "-c", "if command -v satty >/dev/null 2>&1; then wl-paste -t image/png | satty -f -; elif command -v swappy >/dev/null 2>&1; then wl-paste -t image/png | swappy -f -; fi"]);
                                    win.osd = "";
                                }
                            }
                        }
                    }
                }

                // timer_done — interactive popup when countdown finishes
                OsdSlot {
                    id: timerDoneSlot
                    kind: "timer_done"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Icon {
                            id: timerDoneIcon
                            anchors.verticalCenter: parent.verticalCenter
                            name: "alarm"
                            size: Theme.px(15)
                            color: Theme.orange
                            SequentialAnimation on rotation {
                                running: timerDoneSlot.active && win.mode === "osd"
                                loops: Animation.Infinite
                                NumberAnimation { to: 14; duration: 110; easing.type: Easing.InOutSine }
                                NumberAnimation { to: -14; duration: 110; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: 110; easing.type: Easing.InOutSine }
                                PauseAnimation { duration: 350 }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Time's Up!"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.Bold
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.px(22)
                            width: tPlusLbl.implicitWidth + Theme.px(12)
                            radius: height / 2
                            color: tPlusMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09)
                            scale: tPlusMa.pressed ? 0.90 : 1.0
                            Behavior on scale { Spring { epsilon: 0.01 } }

                            Text {
                                id: tPlusLbl
                                anchors.centerIn: parent
                                text: "+1m"
                                color: Theme.orange
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                id: tPlusMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    Timers.setPreset(60);
                                    Timers.toggleStart();
                                    win.osd = "";
                                }
                            }
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.px(22)
                            width: tRepLbl.implicitWidth + Theme.px(12)
                            radius: height / 2
                            color: tRepMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09)
                            scale: tRepMa.pressed ? 0.90 : 1.0
                            Behavior on scale { Spring { epsilon: 0.01 } }

                            Text {
                                id: tRepLbl
                                anchors.centerIn: parent
                                text: "Repeat"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                id: tRepMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    Timers.reset();
                                    Timers.toggleStart();
                                    win.osd = "";
                                }
                            }
                        }
                    }
                }

                // track — iOS-style expanded card with swipe animation on track change
                OsdSlot {
                    id: trackSlot
                    kind: "track"

                    Item {
                        id: trackStage
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(14)
                        anchors.rightMargin: Theme.px(16)

                        // Old card slides out, new card slides in (dir: +1 next → leftwards, -1 prev → rightwards)
                        function swipe(dir) {
                            const dist = Theme.px(56);
                            const hasOut = win.prevTrackTitle !== "" || win.prevTrackSkeleton;
                            swipeAnim.stop();
                            outCard.title = win.prevTrackTitle;
                            outCard.artist = win.prevTrackArtist;
                            outCard.art = win.prevTrackArt;
                            outCard.skeleton = win.prevTrackSkeleton;
                            outCard.x = 0;
                            outCard.scale = 1.0;
                            outCard.opacity = hasOut ? 1.0 : 0.0;
                            inCard.x = dir * dist;
                            inCard.scale = 0.9;
                            inCard.opacity = 0.0;
                            inCard.artScale = 0.82;
                            swipeAnim.dir = dir;
                            swipeAnim.restart();
                        }

                        Connections {
                            target: win
                            function onTrackSwipeSeqChanged() { trackStage.swipe(win.trackSwipeDir); }
                        }

                        ParallelAnimation {
                            id: swipeAnim
                            property int dir: 1
                            NumberAnimation { target: outCard; property: "x"; to: -swipeAnim.dir * Theme.px(56); duration: 260; easing.type: Easing.OutCubic }
                            NumberAnimation { target: outCard; property: "opacity"; to: 0; duration: 200; easing.type: Easing.OutCubic }
                            NumberAnimation { target: outCard; property: "scale"; to: 0.9; duration: 260; easing.type: Easing.OutCubic }
                            NumberAnimation { target: inCard; property: "x"; to: 0; duration: 320; easing.type: Easing.OutCubic }
                            NumberAnimation { target: inCard; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
                            NumberAnimation { target: inCard; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
                            NumberAnimation { target: inCard; property: "artScale"; to: 1.0; duration: 460; easing.type: Easing.OutBack }
                        }

                        Item {
                            id: cardArea
                            anchors.left: parent.left
                            anchors.right: trackRightBox.left
                            anchors.rightMargin: Theme.px(10)
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            clip: true

                            TrackCard {
                                id: outCard
                                width: cardArea.width
                                height: cardArea.height
                                opacity: 0
                                visible: opacity > 0.01
                            }
                            TrackCard {
                                id: inCard
                                width: cardArea.width
                                height: cardArea.height
                                title: win.lastTrackTitle
                                artist: win.lastTrackArtist
                                art: win.lastTrackArt
                                skeleton: win.trackPending
                            }
                        }

                        Item {
                            id: trackRightBox
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: notchHover.hovered ? trackCtrlRow.implicitWidth : trackOsdWave.implicitWidth
                            height: Theme.px(28)
                            Behavior on width { Spring { epsilon: 0.2 } }

                            AudioWave {
                                id: trackOsdWave
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                active: Media.playing && trackSlot.active && !notchHover.hovered
                                opacity: notchHover.hovered ? 0 : 1
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                                color: Media.trackAccent
                                Behavior on color { ColorAnimation { duration: 280 } }
                                maxH: Theme.px(16)
                                minH: Theme.px(3)
                            }

                            Row {
                                id: trackCtrlRow
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.px(4)
                                opacity: notchHover.hovered ? 1 : 0
                                visible: opacity > 0.01
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Repeater {
                                    model: [
                                        { icon: "skip_previous", act: "prev" },
                                        { icon: Media.playing ? "pause" : "play_arrow", act: "play" },
                                        { icon: "skip_next", act: "next" }
                                    ]
                                    Rectangle {
                                        required property var modelData
                                        width: Theme.px(24)
                                        height: Theme.px(24)
                                        radius: width / 2
                                        color: tcMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                                        scale: tcMa.pressed ? 0.86 : 1.0
                                        Behavior on scale { Spring { epsilon: 0.01 } }
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Icon {
                                            anchors.centerIn: parent
                                            name: parent.modelData.icon
                                            size: Theme.px(14)
                                            color: Theme.text
                                        }
                                        MouseArea {
                                            id: tcMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: mouse => {
                                                mouse.accepted = true;
                                                if (parent.modelData.act === "prev") Media.prev();
                                                else if (parent.modelData.act === "play") Media.togglePlay();
                                                else Media.next();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // rec_countdown — pre-record countdown ring (3 · 2 · 1)
                OsdSlot {
                    id: recCdSlot
                    kind: "rec_countdown"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(9)

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(22)
                            height: Theme.px(22)

                            ProgressRing {
                                anchors.centerIn: parent
                                size: Theme.px(22)
                                strokeWidth: Theme.px(2)
                                value: Recorder.countdownTotal > 0 ? Recorder.countdownLeft / Recorder.countdownTotal : 0
                                fillColor: Theme.red
                                trackColor: Qt.rgba(1, 0.27, 0.23, 0.24)
                            }
                            Text {
                                id: cdNum
                                anchors.centerIn: parent
                                text: Recorder.countdownLeft
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.Bold
                                font.features: { "tnum": 1 }

                                Connections {
                                    target: Recorder
                                    function onCountdownTick() { if (recCdSlot.active) cdNumPop.restart(); }
                                }
                                SpringAnimation {
                                    id: cdNumPop
                                    target: cdNum
                                    property: "scale"
                                    from: 1.5
                                    to: 1.0
                                    spring: Theme.springK
                                    damping: Theme.springDamp
                                    epsilon: 0.01
                                }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Recording in…"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // rec_start — recording just began (dot + REC + timer), morphs into the persistent wing
                OsdSlot {
                    id: recStartSlot
                    kind: "rec_start"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(9)

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(14)
                            height: Theme.px(14)

                            Rectangle {
                                id: recHalo
                                anchors.centerIn: parent
                                width: Theme.px(14)
                                height: width
                                radius: width / 2
                                color: Theme.red
                                opacity: 0
                            }
                            Rectangle {
                                id: recDot
                                anchors.centerIn: parent
                                width: Theme.px(8)
                                height: width
                                radius: width / 2
                                color: Theme.red
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "REC"
                            color: Theme.red
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.Bold
                            font.letterSpacing: Theme.px(0.6)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Recorder.elapsedText
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }

                    Connections {
                        target: recStartSlot
                        function onActiveChanged() { if (recStartSlot.active) recStartPop.restart(); }
                    }
                    ParallelAnimation {
                        id: recStartPop
                        NumberAnimation { target: recDot; property: "scale"; from: 1.8; to: 1.0; duration: 380; easing.type: Easing.OutBack }
                        NumberAnimation { target: recHalo; property: "opacity"; from: 0.5; to: 0; duration: 700; easing.type: Easing.OutCubic }
                        NumberAnimation { target: recHalo; property: "scale"; from: 0.6; to: 2.0; duration: 700; easing.type: Easing.OutCubic }
                    }
                }

                // rec_saved — native confirmation when screen recording is saved
                OsdSlot {
                    id: recSavedSlot
                    kind: "rec_saved"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Icon {
                            id: recSavedIcon
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check_circle"
                            size: Theme.px(15)
                            color: Theme.green

                            Connections {
                                target: recSavedSlot
                                function onActiveChanged() { if (recSavedSlot.active) recSavedPop.restart(); }
                            }
                            SpringAnimation {
                                id: recSavedPop
                                target: recSavedIcon
                                property: "scale"
                                from: 0.65
                                to: 1.0
                                spring: Theme.springK
                                damping: Theme.springDamp
                                epsilon: 0.01
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Saved · " + win.lastSavedRecDur
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.px(22)
                            width: Theme.px(22)
                            radius: height / 2
                            color: recPlayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09)
                            scale: recPlayMa.pressed ? 0.90 : 1.0
                            Behavior on scale { Spring { epsilon: 0.01 } }

                            Icon {
                                anchors.centerIn: parent
                                name: "play_arrow"
                                size: Theme.px(13)
                                color: Theme.green
                            }
                            MouseArea {
                                id: recPlayMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    if (win.lastSavedRecFile !== "") Quickshell.execDetached(["xdg-open", win.lastSavedRecFile]);
                                    win.osd = "";
                                }
                            }
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.px(22)
                            width: Theme.px(22)
                            radius: height / 2
                            color: recDirMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09)
                            scale: recDirMa.pressed ? 0.90 : 1.0
                            Behavior on scale { Spring { epsilon: 0.01 } }

                            Icon {
                                anchors.centerIn: parent
                                name: "folder_open"
                                size: Theme.px(12)
                                color: Theme.text
                            }
                            MouseArea {
                                id: recDirMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    Quickshell.execDetached(["xdg-open", Recorder.outDir]);
                                    win.osd = "";
                                }
                            }
                        }
                    }
                }

                // submap — instant feedback when entering Hyprland submap
                OsdSlot {
                    id: submapOsdSlot
                    kind: "submap"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Keyboard.submap.toLowerCase().indexOf("resize") !== -1 ? "open_with"
                                : Keyboard.submap.toLowerCase().indexOf("pass") !== -1 ? "lock_open"
                                : "keyboard_command_key"
                            size: Theme.px(15)
                            color: Theme.orange
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Submap: " + Keyboard.submap.toUpperCase()
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // mic — instant feedback on microphone mute toggle
                OsdSlot {
                    id: micOsdSlot
                    kind: "mic"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Icon {
                            id: micOsdIcon
                            anchors.verticalCenter: parent.verticalCenter
                            name: win.lastMicMutedState ? "mic_off" : "mic"
                            size: Theme.px(15)
                            color: win.lastMicMutedState ? Theme.red : Theme.mint

                            Connections {
                                target: Audio
                                function onMicMuteToggled() { if (micOsdSlot.active && win.mode === "osd") micOsdPop.restart(); }
                            }
                            SpringAnimation {
                                id: micOsdPop
                                target: micOsdIcon
                                property: "scale"
                                from: 0.72
                                to: 1.0
                                spring: Theme.springK
                                damping: Theme.springDamp
                                epsilon: 0.01
                            }
                        }
                        RollingLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.lastMicMutedState ? "Mic Muted" : "Mic Live"
                            color: Theme.text
                            pixelSize: Theme.px(13)
                            fontWeight: Font.DemiBold
                            slotActive: micOsdSlot.active
                            topEnterText: "Mic Muted"
                        }
                    }
                }

                // sink — instant feedback on default audio output switch
                OsdSlot {
                    id: sinkOsdSlot
                    kind: "sink"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Icon {
                            id: sinkOsdIcon
                            anchors.verticalCenter: parent.verticalCenter
                            name: win.lastSinkIcon || "speaker"
                            size: Theme.px(15)
                            color: Theme.blue

                            Connections {
                                target: Audio
                                function onSinkSwitched() { if (sinkOsdSlot.active && win.mode === "osd") sinkOsdPop.restart(); }
                            }
                            SpringAnimation {
                                id: sinkOsdPop
                                target: sinkOsdIcon
                                property: "scale"
                                from: 0.72
                                to: 1.0
                                spring: Theme.springK
                                damping: Theme.springDamp
                                epsilon: 0.01
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, Theme.px(185))
                            elide: Text.ElideRight
                            text: win.lastSinkName || "Audio Output"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // notification matching screenshot #3:
                // Dark pill with circular letter badge (or app icon), appName/summary in subtitle, large bold summary/body
                OsdSlot {
                    id: notifSlot
                    kind: "notif"

                    property real _rollY: 0
                    Connections {
                        target: win
                        function onNotifChanged() {
                            if (notifSlot.active && win.mode === "osd") {
                                notifIconPop.restart();
                                notifRollAnim.restart();
                            }
                        }
                    }
                    NumberAnimation {
                        id: notifRollAnim
                        target: notifSlot
                        property: "_rollY"
                        from: Theme.px(14)
                        to: 0
                        duration: 200
                        easing.type: Easing.OutCubic
                    }

                    // Right-click anywhere on toast dismisses the notification immediately
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                Notifs.dismiss(win.notif);
                                win.osd = "";
                            }
                        }
                    }

                    // Circular Avatar / Badge matching screenshot #3
                    Rectangle {
                        id: notifIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.px(16)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(34)
                        height: width
                        radius: width / 2
                        color: "#181D1C"

                        SpringAnimation {
                            id: notifIconPop
                            target: notifIcon
                            property: "scale"
                            from: 0.72
                            to: 1.0
                            spring: Theme.springK
                            damping: Theme.springDamp
                            epsilon: 0.01
                        }

                        // If app icon is available, display it; otherwise show circular initial letter with mint tint
                        Text {
                            anchors.centerIn: parent
                            visible: notifImg.status !== Image.Ready
                            text: {
                                const n = win.notif;
                                if (!n) return "N";
                                const name = (n.appName || n.summary || "N").trim();
                                return name.charAt(0).toUpperCase();
                            }
                            color: Theme.mint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(14)
                            font.weight: Font.Bold
                        }

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: width / 2
                            visible: notifImg.status === Image.Ready
                            color: "transparent"

                            Image {
                                id: notifImg
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(width * 2, height * 2)
                                source: {
                                    const n = win.notif;
                                    if (!n) return "";
                                    if (n.image) return n.image;
                                    if (n.appIcon) return n.appIcon.indexOf("/") >= 0 ? n.appIcon : Quickshell.iconPath(n.appIcon, true);
                                    return "";
                                }
                            }
                        }
                    }

                    // Notification Text block: app name in muted text on top, summary in bold white, body below
                    Column {
                        anchors.left: notifIcon.right
                        anchors.leftMargin: Theme.px(12)
                        anchors.right: notifActionsRow.visible ? notifActionsRow.left : parent.right
                        anchors.rightMargin: notifActionsRow.visible ? Theme.px(8) : Theme.px(18)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: notifSlot._rollY
                        spacing: Theme.px(1)

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: win.notif ? (win.notif.appName || "notify-send") : "notify-send"
                            color: "#6D7774"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: win.notif ? (win.notif.summary || "hello") : "hello"
                            color: "#F0F4F3"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.Bold
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            visible: text.length > 0
                            text: win.notif ? (win.notif.body || "").replace(/<[^>]*>/g, "") : ""
                            color: "#A2ABA8"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                        }
                    }

                    // Action buttons (if notification provides actions)
                    Row {
                        id: notifActionsRow
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.px(14)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(6)
                        readonly property var acts: (win.notif && win.notif.actions)
                            ? win.notif.actions.filter(a => a && a.id !== "default" && a.text).slice(0, 2)
                            : []
                        visible: acts.length > 0

                        Repeater {
                            model: notifActionsRow.acts
                            Rectangle {
                                required property var modelData
                                height: Theme.px(24)
                                width: Math.min(actLbl.implicitWidth + Theme.px(16), Theme.px(88))
                                radius: height / 2
                                color: actMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                                scale: actMa.pressed ? 0.90 : 1.0
                                Behavior on scale { Spring { epsilon: 0.01 } }

                                Text {
                                    id: actLbl
                                    anchors.centerIn: parent
                                    width: Math.min(implicitWidth, parent.width - Theme.px(10))
                                    elide: Text.ElideRight
                                    text: parent.modelData.text
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(11)
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    id: actMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        mouse.accepted = true;
                                        Notifs.invoke(win.notif, parent.modelData.id);
                                        win.osd = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═════════ PANEL (Dedicated panel inside notch, without dashboard header) ═════════
            Item {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(11)
                anchors.rightMargin: Theme.px(11)
                anchors.bottomMargin: Theme.px(11)
                clip: true

                MorphView {
                    id: panelView
                    shown: win.mode === "panel"
                    hiddenScale: 0.96
                    hiddenY: -Theme.px(6)
                    delayDuration: 0
                    fadeInDuration: 110
                    transformOrigin: Item.Top
                    width: win.activePanelW
                    height: win.activePanelH
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top

                    Item {
                        id: panelArea
                        anchors.centerIn: parent
                        width: win.activePanelInnerW
                        height: panelLoader.item ? panelLoader.item.implicitHeight : 0
                        property real _slideX: 0
                        transform: Translate { x: panelArea._slideX }

                        Connections {
                            target: win
                            function onPanelSwitchSeqChanged() {
                                panelSlideAnim.stop();
                                panelArea._slideX = win.panelSwitchDir * Theme.px(24);
                                panelArea.scale = 0.96;
                                panelArea.opacity = 0.25;
                                panelSlideAnim.restart();
                            }
                        }

                        ParallelAnimation {
                            id: panelSlideAnim
                            NumberAnimation { target: panelArea; property: "_slideX"; to: 0; duration: 210; easing.type: Easing.OutCubic }
                            NumberAnimation { target: panelArea; property: "scale"; to: 1.0; duration: 210; easing.type: Easing.OutCubic }
                            NumberAnimation { target: panelArea; property: "opacity"; to: 1.0; duration: 170; easing.type: Easing.OutCubic }
                        }

                        Loader {
                            id: panelLoader
                            width: parent.width
                            active: win.loadedPanel !== ""
                            source: active ? Qt.resolvedUrl("panels/" + win.loadedPanel.charAt(0).toUpperCase()
                                                            + win.loadedPanel.slice(1) + "Panel.qml") : ""
                            focus: true
                            onLoaded: {
                                if (item.host !== undefined) item.host = win;
                                if (item.width !== undefined) item.width = Qt.binding(() => panelLoader.width);
                                win.focusActivePanel();
                            }
                        }
                    }

                    // Right-click anywhere in open panel returns back to dashboard
                    MouseArea {
                        z: 1000
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        hoverEnabled: false
                        onPressed: mouse => {
                            mouse.accepted = true;
                            win.backToDashboard();
                        }
                    }
                }
            }
        }
    }

    // Floating iPhone Duo secondary Live Activity ring/pill (active when liveActivityStyle === "duo")
    DuoBubble {
        id: duoBubble
        host: win
        compactMode: win.mode === "compact"
        notchHidden: win.notchHidden
        x: notch.x + notch.width + Theme.px(8)
        y: (Theme.compactH - height) / 2
        onShownChanged: {
            if (win.armed && win.mode === "compact") {
                notch.triggerImpulse(shown ? Theme.px(6) : -Theme.px(5), Theme.px(12), 0);
            }
        }
    }

    component StripDivider: Rectangle {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 1
        height: Theme.px(18)
        color: Theme.divider
    }
}
