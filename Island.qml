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

    // Open dedicated panel directly in notch (calling again collapses back into notch)
    function openPanel(name) {
        osd = "";
        if (panel === name) {
            if (panel === "auth") Auth.cancel();
            collapse();
            return;
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
            if (Recorder.recording) Recorder.stop();
            else Recorder.start((win.monitor && win.monitor.name) ? win.monitor.name : "screen");
        } else if (key === "timer") Timers.toggleStart();
        else openPanel(key);
    }

    function showOsd(kind) {
        if ((mode !== "compact" && mode !== "osd") || !armed) return;
        if (!win.isFocusedMonitor) return;
        if (isGameActive && kind !== "notif" && !IslandPrefs.showOsdInGames) return;
        if (kind === "volume" && !IslandPrefs.showVolumeOsd) return;
        if (kind === "layout" && !IslandPrefs.showLayoutOsd) return;
        if (kind === "clipboard" && !IslandPrefs.liveClipboardPulse) return;
        if (kind === "caps" && !IslandPrefs.liveCapsLock) return;
        lastOsd = kind;
        osd = kind;
        osdTimer.interval = kind === "notif" ? Theme.notifMs
                          : kind === "layout" ? Theme.layoutOsdMs
                          : (kind === "clipboard" || kind === "caps" || kind === "dnd") ? 1100
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
    }
    Connections {
        target: Keyboard
        function onSwitched() { win.showOsd("layout"); }
        function onCapsLockChanged() { if (win.armed) win.showOsd("caps"); }
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
    readonly property real instantOsdW: Math.max(compactW, Theme.px(256))
    readonly property bool isInstantOsd: win.lastOsd === "layout" || win.lastOsd === "clipboard" || win.lastOsd === "caps" || win.lastOsd === "dnd"
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

        property real bw: win.mode === "panel" ? win.activePanelW
                        : win.mode === "dashboard" ? win.dashW
                        : win.mode === "osd" ? (win.lastOsd === "notif" ? Theme.notifW
                                              : win.isInstantOsd ? win.instantOsdW
                                              : Theme.osdW)
                        : win.compactW + (compactHovered ? Theme.hoverGrowW : 0)
        property real bh: win.mode === "panel" ? win.activePanelH
                        : win.mode === "dashboard" ? Theme.stripH
                        : win.mode === "osd" ? (win.lastOsd === "notif" ? Theme.notifH
                                              : win.isInstantOsd ? Theme.compactH
                                              : Theme.osdH)
                        : Theme.compactH + (compactHovered ? Theme.hoverGrowH : 0)
        property real rad: (win.mode === "dashboard" || win.mode === "panel") ? Theme.expandedRadius
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

        NotchShape {
            bodyW: notch.bw
            bodyH: notch.bh
            radius: notch.rad
            fillet: Theme.notchFillet
            color: Theme.bg
        }

        HoverHandler {
            id: notchHover
            enabled: !win.notchHidden
            onHoveredChanged: {
                if (hovered) collapseTimer.stop();
                else if (win.mode === "dashboard" && IslandPrefs.autoCollapse && !win.trayMenuOpen) collapseTimer.restart();
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
                    else if (win.mode === "osd" && win.lastOsd === "clipboard") win.openPanel("clipboard");
                    else if (win.mode === "osd" && win.lastOsd === "caps") win.openPanel("settings");
                    else if (win.mode === "dashboard") win.collapse();
                    else if (win.mode === "compact") win.toggle();
                }
                onWheel: w => {
                    if (win.mode === "panel") return;
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

                Behavior on p { Spring { epsilon: 0.002 } }
                Behavior on dashAlpha {
                    NumberAnimation {
                        duration: homeView.isDash ? Theme.fadeIn : Theme.fadeOut
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
                        readonly property bool activeCompact: Notifs.dnd && homeView.p < 0.5
                        readonly property bool activeDash: false
                        readonly property bool active: activeCompact
                        readonly property bool hasNextCompact: weatherItem.showInCompact || compactStatItem.showInCompact || layoutItem.shouldShow
                        readonly property real compactW: activeCompact ? (Theme.px(13) + (hasNextCompact ? Theme.px(5) : 0)) : 0
                        readonly property real dashW: 0
                        width: Math.max(0, compactW * (1 - homeView.p))
                        height: Theme.px(38)
                        opacity: active ? homeView.compactAlpha : 0
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
                                        cache: false
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        sourceSize: Qt.size(64, 64)
                                        visible: status === Image.Ready && source !== ""
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, Theme.px(120))
                                    elide: Text.ElideRight
                                    text: Media.trackTitle !== "" ? Media.trackTitle : (Media.player ? Media.player.identity : "")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(12)
                                    font.weight: Font.Medium
                                }

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: Media.playing ? "equalizer" : "pause"
                                    size: Theme.px(14)
                                    color: Media.playing ? Theme.accent : Theme.text3
                                }
                            }

                            MouseArea {
                                id: medMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                                        Media.togglePlay();
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

                    // 8. Keyboard Layout pill
                    Item {
                        id: layoutItem
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool shouldShow: Keyboard.shortCode !== ""
                        readonly property real compactW: shouldShow ? kbTxt.implicitWidth : 0
                        readonly property real dashW: shouldShow ? (kbTxt.implicitWidth + Theme.px(12) + (SystemTray.items.values.length > 0 ? Theme.px(12) : 0)) : 0
                        width: Math.max(0, compactW + (dashW - compactW) * homeView.p)
                        height: Theme.px(38)
                        opacity: shouldShow ? 1 : 0
                        clip: true

                        Rectangle {
                            id: kbPill
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: kbTxt.implicitWidth + Theme.px(12) * homeView.p
                            height: Theme.px(20) + Theme.px(4) * homeView.p
                            radius: Theme.px(7)
                            color: homeView.isDash ? (kbMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)) : Qt.rgba(1, 1, 1, 0.07 * homeView.p)
                            scale: (homeView.isDash && kbMa.pressed) ? 0.90 : (homeView.isDash && kbMa.containsMouse ? 1.05 : 1.0)
                            Behavior on scale { Spring { epsilon: 0.01 } }

                            Text {
                                id: kbTxt
                                anchors.centerIn: parent
                                text: Keyboard.shortCode
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
                    y: Theme.px(52) - Theme.px(12) * (1 - homeView.p)
                    implicitWidth: dockInner.implicitWidth + Theme.px(14)
                    width: implicitWidth
                    height: Theme.px(36)
                    radius: Theme.px(13)
                    color: Qt.rgba(1, 1, 1, 0.06)
                    transformOrigin: Item.Top
                    opacity: homeView.dashAlpha
                    scale: 0.85 + 0.15 * homeView.p
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
                     : win.isInstantOsd ? win.instantOsdW
                     : Theme.osdW
                height: win.lastOsd === "notif" ? Theme.notifH
                      : win.isInstantOsd ? Theme.compactH
                      : Theme.osdH
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                // volume
                Item {
                    anchors.fill: parent
                    visible: win.lastOsd === "volume"

                    Icon {
                        id: osdVolIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.px(18)
                        anchors.verticalCenter: parent.verticalCenter
                        name: Audio.icon
                        size: Theme.px(18)
                        color: Audio.muted ? Theme.red : Theme.text
                    }
                    Bar {
                        anchors.left: osdVolIcon.right
                        anchors.right: osdVolText.left
                        anchors.leftMargin: Theme.px(12)
                        anchors.rightMargin: Theme.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        height: Theme.px(6)
                        value: Audio.muted ? 0 : Audio.volume
                        tint: Theme.text
                    }
                    Text {
                        id: osdVolText
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.px(18)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(30)
                        horizontalAlignment: Text.AlignRight
                        text: Audio.muted ? "off" : Math.round(Audio.volume * 100)
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(13)
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                }

                // layout — compact popup sized to the notch
                Item {
                    anchors.fill: parent
                    visible: win.lastOsd === "layout"

                    Row {
                        id: layoutOsdRow
                        anchors.centerIn: parent
                        spacing: Theme.px(9)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "language"
                            size: Theme.px(15)
                            color: Theme.blue
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Keyboard.shortCode
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.Bold
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Keyboard.layout
                            width: Math.min(implicitWidth, Theme.px(130))
                            elide: Text.ElideRight
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.Medium
                        }
                    }
                }

                // clipboard — compact popup sized to the notch
                Item {
                    anchors.fill: parent
                    visible: win.lastOsd === "clipboard"

                    Row {
                        id: clipboardOsdRow
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "content_paste"
                            size: Theme.px(15)
                            color: Theme.mint
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Copied"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // dnd — compact popup sized to the notch
                Item {
                    anchors.fill: parent
                    visible: win.lastOsd === "dnd"

                    Row {
                        id: dndOsdRow
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Notifs.dnd ? "notifications_off" : "notifications_active"
                            size: Theme.px(15)
                            color: Notifs.dnd ? Theme.purple : Theme.mint
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Notifs.dnd ? "Do Not Disturb" : "Notifications On"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // caps — compact popup sized to the notch
                Item {
                    anchors.fill: parent
                    visible: win.lastOsd === "caps"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "keyboard_capslock"
                            size: Theme.px(15)
                            color: Keyboard.capsLock ? Theme.warn : Theme.text2
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Keyboard.capsLock ? "Caps Lock ON" : "Caps Lock OFF"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // notification matching screenshot #3:
                // Dark pill with circular letter badge (or app icon), appName/summary in subtitle, large bold summary/body
                Item {
                    anchors.fill: parent
                    visible: win.lastOsd === "notif"

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
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.px(18)
                        anchors.verticalCenter: parent.verticalCenter
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
                    hiddenScale: 0.85
                    hiddenY: -Theme.px(12)
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
                                appear.restart();
                                win.focusActivePanel();
                            }
                            ParallelAnimation {
                                id: appear
                                NumberAnimation { target: panelLoader; property: "opacity"; from: 0; to: 1; duration: Theme.fadeIn; easing.type: Easing.OutCubic }
                                SpringAnimation { target: panelLoader; property: "scale"; from: 0.96; to: 1; spring: Theme.springK; damping: Theme.springDamp; epsilon: 0.01 }
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
    }

    component StripDivider: Rectangle {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 1
        height: Theme.px(18)
        color: Theme.divider
    }
}
