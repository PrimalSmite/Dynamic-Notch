import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.services
import qs.components

// «Чёлка» на каждом мониторе.
// Режимы:
//   compact   — капсулы рабочих столов (слева) · время строго по центру · активности и раскладка (справа)
//   osd       — плашка при смене громкости / раскладки или новом уведомлении
//   dashboard — двухрядный компактный дашборд (статус + трей сверху, док иконок снизу)
//   panel     — отдельная панель (лончер, уведомления, polkit-пароль и т.д.) прямо в чёлке без шапки дашборда
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: modelData ? modelData.height : Theme.px(1080)
    color: "transparent"

    exclusiveZone: Theme.compactH
    WlrLayershell.namespace: "dynamic-island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: (mode === "dashboard" || mode === "panel")
                                 ? WlrKeyboardFocus.Exclusive
                                 : WlrKeyboardFocus.None
    mask: Region { item: (win.mode === "dashboard" || win.mode === "panel") ? outsideCatcher : notch }

    // Инициализируем менеджер HyprlandFocusGrab заранее, чтобы первый захват не терялся
    Timer {
        interval: 80
        running: true
        onTriggered: {
            focusGrab.active = true;
            focusGrab.active = false;
        }
    }

    // Защита от ложного срабатывания HyprlandFocusGrab в момент перехвата Exclusive-фокуса
    property bool grabArmed: false
    Timer {
        id: grabArmTimer
        interval: 180
        onTriggered: {
            if (win.mode === "dashboard" || win.mode === "panel") {
                win.grabArmed = true;
                focusGrab.active = false;
                focusGrab.active = true;
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [win]
        active: (win.mode === "dashboard" || win.mode === "panel") && win.grabArmed
        onCleared: {
            if (!win.grabArmed) return;
            if (win.panel === "auth") Auth.cancel();
            win.collapse();
        }
    }

    // ───────── Состояние ─────────
    property bool expanded: false       // открыт ли сам дашборд
    property string panel: ""           // открытая отдельная панель ("" — нет панели)
    property string loadedPanel: ""     // держим содержимое во время анимации закрытия
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

    // Открыть отдельную панель прямо в чёлке (повторный вызов сворачивает обратно в чёлку)
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

    // Вернуться из открытой панели назад в дашборд (по ПКМ или Backspace)
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
        else if (key === "recorder") {
            if (Recorder.recording) Recorder.stop();
            else Recorder.start((win.monitor && win.monitor.name) ? win.monitor.name : "screen");
        } else if (key === "timer") Timers.toggleStart();
        else openPanel(key);
    }

    function showOsd(kind) {
        if ((mode !== "compact" && mode !== "osd") || !armed) return;
        if (monitor && !monitor.focused) return;
        if (kind === "volume" && !IslandPrefs.showVolumeOsd) return;
        if (kind === "layout" && !IslandPrefs.showLayoutOsd) return;
        lastOsd = kind;
        osd = kind;
        osdTimer.interval = kind === "notif" ? Theme.notifMs
                          : kind === "layout" ? Theme.layoutOsdMs
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
    Timer { id: collapseTimer; interval: 650; onTriggered: if (win.mode === "dashboard") win.collapse() }
    Timer { id: unloadTimer; interval: 300; onTriggered: if (win.panel === "") win.loadedPanel = "" }

    Connections {
        target: Audio
        function onVolumeChanged() { win.showOsd("volume"); }
        function onMutedChanged() { win.showOsd("volume"); }
    }
    Connections {
        target: Keyboard
        function onSwitched() { win.showOsd("layout"); }
    }
    Connections {
        target: Notifs
        function onPopup(n) { win.notif = n; win.showOsd("notif"); }
    }
    Connections {
        target: Auth
        function onRequested() {
            if (win.monitor && !win.monitor.focused) return;
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
            if (win.monitor && !win.monitor.focused) return;
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
            if (win.monitor && !win.monitor.focused) {
                if (win.mode === "dashboard" || win.mode === "panel") win.collapse();
                return;
            }
            win.openPanel(name);
        }
        function onCycleRequested(delta) {
            if (win.monitor && !win.monitor.focused) return;
            win.cyclePanel(delta);
        }
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // ───────── Размеры ─────────
    // Равномерная ширина свёрнутого Notch с гармоничными отступами без пустот
    readonly property real compactW: wsCompact.implicitWidth + clockText.implicitWidth + rightCompact.implicitWidth + Theme.px(11) * 2 + Theme.px(16) * 2
    readonly property real layoutOsdW: Math.max(compactW, layoutOsdRow.implicitWidth + Theme.px(32))
    readonly property real dashW: Math.max(Theme.px(520),
                                  Math.max(topRow.implicitWidth, dockBar.implicitWidth) + Theme.px(36))
    readonly property real activePanelInnerW: (panelLoader.item && panelLoader.item.implicitWidth > 0)
                                              ? panelLoader.item.implicitWidth
                                              : Theme.px(600)
    readonly property real activePanelW: activePanelInnerW + 2 * Theme.pad
    readonly property real activePanelH: (panelLoader.item ? panelLoader.item.implicitHeight : Theme.px(200))
                                         + 2 * Theme.pad

    // ───────── Перехват клика мимо открытой панели / дашборда ─────────
    MouseArea {
        id: outsideCatcher
        anchors.fill: parent
        enabled: win.mode === "dashboard" || win.mode === "panel"
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            if (win.panel === "auth") Auth.cancel();
            win.collapse();
        }
    }

    // ───────── Чёлка ─────────
    Item {
        id: notch

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: bw + 2 * Theme.notchFillet
        height: bh

        readonly property bool compactHovered: notchHover.hovered && win.mode === "compact"

        property real bw: win.mode === "panel" ? win.activePanelW
                        : win.mode === "dashboard" ? win.dashW
                        : win.mode === "osd" ? (win.lastOsd === "notif" ? Theme.notifW
                                              : win.lastOsd === "layout" ? win.layoutOsdW
                                              : Theme.osdW)
                        : win.compactW + (compactHovered ? Theme.hoverGrowW : 0)
        property real bh: win.mode === "panel" ? win.activePanelH
                        : win.mode === "dashboard" ? Theme.stripH
                        : win.mode === "osd" ? (win.lastOsd === "notif" ? Theme.notifH
                                              : win.lastOsd === "layout" ? Theme.compactH
                                              : Theme.osdH)
                        : Theme.compactH + (compactHovered ? Theme.hoverGrowH : 0)
        property real rad: (win.mode === "dashboard" || win.mode === "panel") ? Theme.expandedRadius
                         : Theme.compactRadius + (compactHovered ? Theme.px(2) : 0)
        property real cw: win.compactW + (compactHovered ? Theme.hoverGrowW : 0)
        property real ch: Theme.compactH + (compactHovered ? Theme.hoverGrowH : 0)
        Behavior on bw { Spring {} }
        Behavior on bh { Spring {} }
        Behavior on rad { Spring {} }
        Behavior on cw { Spring {} }
        Behavior on ch { Spring {} }

        // Блокируем проваливание кликов по «ушкам» чёлки в outsideCatcher
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
            onHoveredChanged: {
                if (hovered) collapseTimer.stop();
                else if (win.mode === "dashboard" && IslandPrefs.autoCollapse) collapseTimer.restart();
            }
        }

        FocusScope {
            id: body
            x: Theme.notchFillet
            width: notch.bw
            height: notch.bh
            clip: true
            focus: true

            // Глобальные горячие клавиши (Esc всегда сворачивает обратно в маленький Notch)
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
                    if (win.mode === "dashboard") { win.openPanel("mixer"); event.accepted = true; }
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

            // Фон: ЛКМ — раскрыть дашборд, ПКМ — назад в дашборд (из панели) или лончер (из чёлки), СКМ — пауза/музыка, колесо — рабочие столы
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
                        }
                        return;
                    }
                    if (win.mode === "osd" && win.lastOsd === "notif") win.openPanel("notifications");
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

            // ═════════ COMPACT (Часы строго по центру, капсулы столов слева, погода и раскладка справа) ═════════
            MorphView {
                id: compactView
                shown: win.mode === "compact"
                hiddenScale: 0.85
                hiddenY: -Theme.px(6)
                transformOrigin: Item.Top
                width: notch.cw
                height: notch.ch
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(11)
                    scale: notch.compactHovered ? 1.04 : 1.0
                    Behavior on scale { Spring { epsilon: 0.002 } }

                    // Левая часть: вертикальные капсулы рабочих столов
                    Workspaces {
                        id: wsCompact
                        monitor: win.monitor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Центр: перелистывающиеся часы
                    RollingClock {
                        id: clockText
                        anchors.verticalCenter: parent.verticalCenter
                        timeString: Qt.formatTime(clock.date, IslandPrefs.showSeconds ? "HH:mm:ss" : "HH:mm")
                        fontSize: Theme.px(14)
                        fontWeight: Font.DemiBold
                        textColor: Theme.text
                    }

                    // Правая часть: живые активности + виджет + раскладка
                    Row {
                        id: rightCompact
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(7)

                        // запись экрана (пульсирующий ореол + дыхание масштаба + перелистывание цифр)
                        Row {
                            visible: Recorder.recording
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(5)

                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(10); height: width

                                // Расходящийся ореол (Halo)
                                Rectangle {
                                    id: recHalo
                                    anchors.centerIn: parent
                                    width: Theme.px(7); height: width; radius: width / 2
                                    color: Theme.red
                                    opacity: 0
                                    scale: 1
                                    ParallelAnimation {
                                        running: Recorder.recording
                                        loops: Animation.Infinite
                                        NumberAnimation { target: recHalo; property: "scale"; from: 0.9; to: 2.3; duration: 1400; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: recHalo; property: "opacity"; from: 0.55; to: 0.0; duration: 1400; easing.type: Easing.OutCubic }
                                    }
                                }

                                // Ядро индикатора с синусоидальным дыханием масштаба
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Theme.px(7); height: width; radius: width / 2
                                    color: Theme.red
                                    SequentialAnimation on scale {
                                        running: Recorder.recording
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 1.16; duration: 700; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 0.88; duration: 700; easing.type: Easing.InOutSine }
                                    }
                                }
                            }

                            RollingClock {
                                anchors.verticalCenter: parent.verticalCenter
                                timeString: Recorder.elapsedText
                                fontSize: Theme.px(12)
                                fontWeight: Font.DemiBold
                                textColor: Theme.red
                            }
                            TapHandler { onTapped: win.openPanel("recorder") }
                        }

                        // таймер / секундомер (с микро-импульсом иконки и перелистыванием секунд)
                        Row {
                            visible: Timers.running
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(3)
                            Icon {
                                id: timerCompactIcon
                                anchors.verticalCenter: parent.verticalCenter
                                name: Timers.mode === "stopwatch" ? "timer_play" : "timer"
                                size: Theme.px(13)
                                color: Theme.orange
                                SpringAnimation {
                                    id: timerTickPulse
                                    target: timerCompactIcon
                                    property: "scale"
                                    from: 1.18
                                    to: 1.0
                                    spring: Theme.springK
                                    damping: Theme.springDamp
                                    epsilon: 0.003
                                }
                            }
                            RollingClock {
                                anchors.verticalCenter: parent.verticalCenter
                                timeString: Timers.display
                                fontSize: Theme.px(12)
                                fontWeight: Font.DemiBold
                                textColor: Theme.orange
                                onTimeStringChanged: {
                                    if (Timers.running) timerTickPulse.restart();
                                }
                            }
                            TapHandler { onTapped: win.openPanel("timer") }
                        }


                        // непрочитанные уведомления / не беспокоить
                        Icon {
                            visible: Notifs.dnd
                            anchors.verticalCenter: parent.verticalCenter
                            name: "do_not_disturb_on"
                            size: Theme.px(13)
                            color: Theme.purple
                        }
                        Rectangle {
                            visible: !Notifs.dnd && Notifs.unread > 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(6); height: width; radius: width / 2
                            color: Theme.accent
                        }

                        // Настраиваемый виджет чёлки (Погода / ЦП / Сеть / Выкл)
                        Row {
                            visible: IslandPrefs.compactWidget !== "none"
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(3)

                            // 1. Погода
                            Icon {
                                visible: IslandPrefs.compactWidget === "weather"
                                anchors.verticalCenter: parent.verticalCenter
                                name: Weather.ready ? Weather.icon : "thermostat"
                                size: Theme.px(13)
                                color: Weather.ready ? Theme.yellow : Theme.blue
                            }
                            Text {
                                visible: IslandPrefs.compactWidget === "weather"
                                anchors.verticalCenter: parent.verticalCenter
                                text: Weather.ready && !isNaN(Weather.temp)
                                      ? (Math.round(Weather.temp) + "°")
                                      : (SysInfo.cpuTemp > 0 ? Math.round(SysInfo.cpuTemp) + "°" : Math.round(SysInfo.cpu * 100) + "%")
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }

                            // 2. ЦП и температура
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

                            // 3. Сеть (LAN загрузка)
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
                                onTapped: {
                                    if (IslandPrefs.compactWidget === "weather" && Weather.ready) win.openPanel("weather");
                                    else win.openPanel("sysmon");
                                }
                            }
                        }

                        // раскладка — просто текст, клик переключает
                        Text {
                            visible: Keyboard.short !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: Keyboard.short
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.Bold
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -Theme.px(5)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Keyboard.next()
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
                     : win.lastOsd === "layout" ? win.layoutOsdW
                     : Theme.osdW
                height: win.lastOsd === "notif" ? Theme.notifH
                      : win.lastOsd === "layout" ? Theme.compactH
                      : Theme.osdH
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                // громкость
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

                // раскладка — компактная плашка размером с сам notch
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
                            text: Keyboard.short
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.Bold
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Keyboard.layout
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.Medium
                        }
                    }
                }

                // уведомление
                Item {
                    anchors.fill: parent
                    visible: win.lastOsd === "notif"

                    ClippingRectangle {
                        id: notifIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.px(14)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(38); height: width
                        radius: Theme.px(10)
                        color: Theme.card
                        Icon {
                            anchors.centerIn: parent
                            name: "notifications"
                            visible: notifImg.status !== Image.Ready
                        }
                        Image {
                            id: notifImg
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
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
                            text: win.notif ? (win.notif.summary || win.notif.appName) : ""
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            text: win.notif ? (win.notif.body || win.notif.appName).replace(/<[^>]*>/g, "") : ""
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(12)
                        }
                    }
                }
            }

            // ═════════ DASHBOARD (Двухрядный компактный дашборд с системным треем) ═════════
            Item {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(15)
                anchors.rightMargin: Theme.px(15)
                anchors.bottomMargin: Theme.px(5)
                clip: true

                MorphView {
                    id: dashboardView
                    shown: win.mode === "dashboard"
                    hiddenScale: 0.85
                    hiddenY: -Theme.px(12)
                    transformOrigin: Item.Top
                    width: win.dashW
                    height: Theme.stripH
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top

                Column {
                    id: strip
                    width: parent.width
                    height: Theme.stripH
                    topPadding: Theme.px(8)
                    spacing: Theme.px(6)

                    // РЯД 1: Рабочие столы · Часы/Календарь · Погода · Медиа · Раскладка · Системный трей
                    Row {
                        id: topRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: Theme.px(38)
                        spacing: Theme.px(12)

                        Workspaces {
                            anchors.verticalCenter: parent.verticalCenter
                            monitor: win.monitor
                        }

                        StripDivider {}

                        // время и дата → календарь [C]
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: clkRow.implicitWidth + Theme.px(16)
                            height: Theme.px(32)
                            radius: Theme.px(10)
                            color: clkMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            scale: clkMa.pressed ? 0.93 : (clkMa.containsMouse ? 1.03 : 1.0)
                            Behavior on scale { Spring { epsilon: 0.002 } }

                            Row {
                                id: clkRow
                                anchors.centerIn: parent
                                spacing: Theme.px(7)

                                RollingClock {
                                    anchors.verticalCenter: parent.verticalCenter
                                    timeString: Qt.formatTime(clock.date, IslandPrefs.showSeconds ? "HH:mm:ss" : "HH:mm")
                                    fontSize: Theme.px(17)
                                    fontWeight: Font.Bold
                                    textColor: Theme.text
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: clock.date.toLocaleDateString(Qt.locale("ru_RU"), "ddd d MMM").replace(/\./g, "").toUpperCase()
                                    color: Theme.text2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(10)
                                    font.weight: Font.Bold
                                    font.letterSpacing: Theme.px(1)
                                }
                            }
                            MouseArea {
                                id: clkMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.openPanel("calendar")
                            }
                        }

                        // погода → [W], ПКМ — обновить
                        Rectangle {
                            visible: Weather.ready
                            anchors.verticalCenter: parent.verticalCenter
                            width: wthRow.implicitWidth + Theme.px(14)
                            height: Theme.px(32)
                            radius: Theme.px(10)
                            color: wthMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            scale: wthMa.pressed ? 0.93 : (wthMa.containsMouse ? 1.03 : 1.0)
                            Behavior on scale { Spring { epsilon: 0.002 } }

                            Row {
                                id: wthRow
                                anchors.centerIn: parent
                                spacing: Theme.px(5)
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: Weather.icon
                                    size: Theme.px(16)
                                    color: Theme.yellow
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


                        // быстрый индикатор раскладки
                        Rectangle {
                            visible: Keyboard.short !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            width: kbTxt.implicitWidth + Theme.px(12)
                            height: Theme.px(24)
                            radius: Theme.px(7)
                            color: kbMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                            scale: kbMa.pressed ? 0.90 : (kbMa.containsMouse ? 1.05 : 1.0)
                            Behavior on scale { Spring { epsilon: 0.002 } }
                            Text {
                                id: kbTxt
                                anchors.centerIn: parent
                                text: Keyboard.short
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                id: kbMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Keyboard.next()
                            }
                        }

                        StripDivider { visible: SystemTray.items.values.length > 0 }

                        // Системный трей (вместо закреплённых приложений)
                        Row {
                            visible: SystemTray.items.values.length > 0
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
                                    Behavior on scale { Spring { epsilon: 0.002 } }

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
                                                if (it.hasMenu) it.display(win, Math.round(pt.x), Math.round(pt.y));
                                                else it.secondaryActivate();
                                            } else if (mouse.button === Qt.MiddleButton) {
                                                it.secondaryActivate();
                                            } else {
                                                if (it.onlyMenu && it.hasMenu) it.display(win, Math.round(pt.x), Math.round(pt.y));
                                                else it.activate();
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

                    // РЯД 2: Чистая капсула док-иконок (без надписи справа)
                    Rectangle {
                        id: dockBar
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: dockInner.implicitWidth + Theme.px(14)
                        width: implicitWidth
                        height: Theme.px(36)
                        radius: Theme.px(13)
                        color: Qt.rgba(1, 1, 1, 0.06)

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
            }
            }

            // ═════════ PANEL (Отдельная панель прямо в чёлке, без шапки дашборда) ═════════
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
                                SpringAnimation { target: panelLoader; property: "scale"; from: 0.96; to: 1; spring: Theme.springK; damping: Theme.springDamp; epsilon: 0.002 }
                            }
                        }
                    }

                    // ПКМ по любой точке открытой панели возвращает назад в дашборд
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

    component StripDivider: Rectangle {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 1
        height: Theme.px(18)
        color: Theme.divider
    }
}
