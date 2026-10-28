import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components

// «Чёлка» на каждом мониторе.
// Режимы:
//   compact  — рабочие столы · время · живые активности (запись, таймер, уведомления) · раскладка
//   osd      — плашка при смене громкости / раскладки или новом уведомлении
//   expanded — верхняя строка (как дашборд) + выезжающая под ней панель
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)

    anchors.top: true
    implicitWidth: Theme.px(1240)
    implicitHeight: Theme.px(680)
    color: "transparent"

    exclusiveZone: Theme.compactH
    WlrLayershell.namespace: "dynamic-island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: notch }

    // клик мимо раскрытой чёлки — свернуть
    HyprlandFocusGrab {
        windows: [win]
        active: win.expanded
        onCleared: win.collapse()
    }

    // ───────── Состояние ─────────
    property bool expanded: false
    property string panel: ""           // открытая панель под строкой ("" — только шапка дашборда)
    property string loadedPanel: ""     // держим содержимое, пока панель закрывается
    property string osd: ""             // "", "volume", "layout", "notif"
    property string lastOsd: "volume"
    property var notif: null            // уведомление для всплывашки
    property string hoveredHint: ""     // подсказка при наведении на иконку док-панели
    readonly property string mode: expanded ? "expanded" : osd !== "" ? "osd" : "compact"

    readonly property var panelOrder: [
        "launcher", "notifications", "mixer", "sysmon", "recorder",
        "timer", "wallpaper", "clipboard", "notes", "settings", "power"
    ]

    readonly property var dockItems: [
        { key: "launcher",      icon: "apps",               label: "Приложения",  hint: "1" },
        { key: "notifications", icon: "notifications",      label: "Уведомления", hint: "2" },
        { key: "mixer",         icon: "tune",               label: "Микшер",      hint: "3" },
        { key: "sysmon",        icon: "monitoring",         label: "Система",     hint: "4" },
        { key: "recorder",      icon: "videocam",           label: "Запись",      hint: "5" },
        { key: "timer",         icon: "timer",              label: "Таймер",      hint: "6" },
        { key: "wallpaper",     icon: "wallpaper",          label: "Обои",        hint: "7" },
        { key: "clipboard",     icon: "content_paste",      label: "Буфер",       hint: "8" },
        { key: "notes",         icon: "edit_note",          label: "Заметки",     hint: "9" },
        { key: "settings",      icon: "settings",           label: "Настройки",   hint: "0" },
        { key: "power",         icon: "power_settings_new", label: "Питание",     hint: "-" }
    ]

    // API для панелей (панель получает его как host)
    function openPanel(name) {
        osd = "";
        expanded = true;
        panel = (panel === name) ? "" : name;
        if (panel !== "") loadedPanel = panel;
        else body.forceActiveFocus();
    }
    function closePanel() {
        panel = "";
        body.forceActiveFocus();
    }
    function collapse() {
        expanded = false;
        panel = "";
    }
    function toggle() {
        osd = "";
        if (expanded) collapse();
        else {
            expanded = true;
            body.forceActiveFocus();
        }
    }
    function cyclePanel(delta) {
        osd = "";
        expanded = true;
        const list = panelOrder;
        const cur = list.indexOf(panel);
        let next = 0;
        if (cur < 0) next = delta > 0 ? 0 : list.length - 1;
        else next = (cur + delta + list.length) % list.length;
        panel = list[next];
        loadedPanel = panel;
    }
    function handleRightClick(key) {
        if (key === "notifications") Notifs.dnd = !Notifs.dnd;
        else if (key === "mixer") Audio.toggleMute();
        else if (key === "recorder") {
            if (Recorder.recording) Recorder.stop();
            else Recorder.start(win.monitor?.name || "screen");
        } else if (key === "timer") Timers.toggleStart();
        else openPanel(key);
    }
    function showOsd(kind) {
        if (expanded || !armed) return;
        if (monitor && !monitor.focused) return;
        lastOsd = kind;
        osd = kind;
        osdTimer.interval = kind === "notif" ? Theme.notifMs
                          : kind === "layout" ? Theme.layoutOsdMs
                          : Theme.osdMs;
        osdTimer.restart();
    }

    onExpandedChanged: {
        if (expanded) body.forceActiveFocus();
    }

    onPanelChanged: {
        if (panel === "") unloadTimer.restart();
        else unloadTimer.stop();
        if (panel === "notifications") Notifs.markRead();
    }

    property bool armed: false
    Timer { interval: 1500; running: true; onTriggered: win.armed = true }
    Timer { id: osdTimer; interval: Theme.osdMs; onTriggered: win.osd = "" }
    Timer { id: collapseTimer; interval: 650; onTriggered: if (win.panel === "") win.collapse() }
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
        target: IslandIpc
        function onToggleRequested() {
            if (win.monitor && !win.monitor.focused) return;
            win.toggle();
        }
        function onCloseRequested() { win.collapse(); }
        function onOpenRequested(name) {
            if (win.monitor && !win.monitor.focused) return;
            if (win.panel === name && win.expanded) { win.collapse(); return; }
            win.openPanel(name);
        }
        function onCycleRequested(delta) {
            if (win.monitor && !win.monitor.focused) return;
            win.cyclePanel(delta);
        }
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // ───────── Размеры ─────────
    readonly property real compactW: Theme.px(15) * 2 + wsCompact.implicitWidth + clockText.implicitWidth
                                     + rightCompact.implicitWidth + Theme.px(14) * 2
    readonly property real layoutOsdW: Math.max(compactW, layoutOsdRow.implicitWidth + Theme.px(32))
    readonly property real stripW: Math.max(Theme.px(650),
                                   Math.max(topRow.implicitWidth, dockBar.implicitWidth) + Theme.px(36))
    readonly property real panelW: stripW - 2 * Theme.pad

    // ───────── Чёлка ─────────
    Item {
        id: notch

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: bw + 2 * Theme.notchFillet
        height: bh

        readonly property bool compactHovered: notchHover.hovered && win.mode === "compact"

        property real bw: win.mode === "expanded" ? win.stripW
                        : win.mode === "osd" ? (win.lastOsd === "notif" ? Theme.notifW
                                              : win.lastOsd === "layout" ? win.layoutOsdW
                                              : Theme.osdW)
                        : win.compactW + (compactHovered ? Theme.hoverGrowW : 0)
        property real bh: win.mode === "expanded" ? expandedView.implicitHeight
                        : win.mode === "osd" ? (win.lastOsd === "notif" ? Theme.notifH
                                              : win.lastOsd === "layout" ? Theme.compactH
                                              : Theme.osdH)
                        : Theme.compactH + (compactHovered ? Theme.hoverGrowH : 0)
        property real rad: win.mode === "expanded" ? Theme.expandedRadius
                         : Theme.compactRadius + (compactHovered ? Theme.px(2) : 0)
        Behavior on bw { Spring {} }
        Behavior on bh { Spring {} }
        Behavior on rad { Spring {} }

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
                else if (win.expanded && win.panel === "") collapseTimer.restart();
            }
        }

        FocusScope {
            id: body
            x: Theme.notchFillet
            width: notch.bw
            height: notch.bh
            clip: true
            focus: true

            // Глобальные горячие клавиши дашборда
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (win.panel !== "") win.closePanel();
                    else win.collapse();
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
                const textFocused = panelLoader.item && panelLoader.item.wantsTextInput === true && !alt;
                if (textFocused) return;

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
                    if (win.panel === "") { win.openPanel("media"); event.accepted = true; }
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
                    if (win.panel === "" || win.panel === "media") {
                        if (Media.player && Media.player.canTogglePlaying) Media.player.togglePlaying();
                        else win.openPanel("launcher");
                        event.accepted = true;
                    }
                    break;
                }
            }

            // Фон: ЛКМ — раскрыть/свернуть, ПКМ — сразу лаунчер, СКМ — пауза/музыка, колесо — рабочие столы
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
                    if (mouse.button === Qt.RightButton && win.mode === "compact") {
                        win.openPanel("launcher");
                        return;
                    }
                    if (win.mode === "osd" && win.lastOsd === "notif") win.openPanel("notifications");
                    else if (win.mode === "expanded") { if (win.panel === "") win.collapse(); }
                    else win.toggle();
                }
                onWheel: w => {
                    acc += w.angleDelta.y;
                    if (Math.abs(acc) < 120) return;
                    wsCompact.go(wsCompact.activeId + (acc > 0 ? -1 : 1));
                    acc = 0;
                }
            }

            // ═════════ COMPACT ═════════
            MorphView {
                id: compactView
                shown: win.mode === "compact"
                width: notch.bw
                height: notch.bh
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(14) + (notch.compactHovered ? Theme.px(2) : 0)
                    scale: notch.compactHovered ? 1.04 : 1.0
                    Behavior on spacing { Spring {} }
                    Behavior on scale { Spring {} }

                    Workspaces {
                        id: wsCompact
                        monitor: win.monitor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: clockText
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatTime(clock.date, "HH:mm")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(14)
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }

                    // живые активности + раскладка
                    Row {
                        id: rightCompact
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(8)

                        // запись экрана (клик — открыть панель записи, ПКМ — стоп)
                        Row {
                            visible: Recorder.recording
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(4)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(7); height: width; radius: width / 2
                                color: Theme.red
                                SequentialAnimation on opacity {
                                    running: Recorder.recording
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Recorder.elapsedText
                                color: Theme.red
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                            TapHandler { onTapped: win.openPanel("recorder") }
                        }

                        // таймер / секундомер (клик — открыть таймер)
                        Row {
                            visible: Timers.running
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(3)
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: Timers.mode === "stopwatch" ? "timer_play" : "timer"
                                size: Theme.px(13)
                                color: Theme.orange
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Timers.display
                                color: Theme.orange
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
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

            // ═════════ EXPANDED (Двухрядный компактный дашборд) ═════════
            MorphView {
                id: expandedView
                shown: win.mode === "expanded"
                hiddenScale: 0.92
                transformOrigin: Item.Top
                width: win.stripW
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                implicitHeight: Theme.stripH + (win.panel !== "" && panelLoader.item
                                ? panelLoader.item.implicitHeight + Theme.pad : 0)

                // ── Шапка дашборда (2 ряда: статус + док вкладок) ──
                Column {
                    id: strip
                    width: parent.width
                    height: Theme.stripH
                    topPadding: Theme.px(8)
                    spacing: Theme.px(6)

                    // РЯД 1: Рабочие столы · Часы/Календарь · Погода · Медиа · Раскладка · Закреплённые приложения
                    Row {
                        id: topRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: Theme.px(38)
                        spacing: Theme.px(12)

                        Workspaces {
                            anchors.verticalCenter: parent.verticalCenter
                            monitor: win.monitor
                            dot: Theme.px(7)
                            activeW: Theme.px(20)
                            spacing: Theme.px(5)
                            activeColor: Theme.accent
                        }

                        StripDivider {}

                        // время и дата → календарь [C]
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: clkRow.implicitWidth + Theme.px(16)
                            height: Theme.px(32)
                            radius: Theme.px(10)
                            color: win.panel === "calendar" ? Qt.rgba(1, 1, 1, 0.14)
                                 : clkMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                            Row {
                                id: clkRow
                                anchors.centerIn: parent
                                spacing: Theme.px(7)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Qt.formatTime(clock.date, "HH:mm")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(17)
                                    font.weight: Font.Bold
                                    font.features: { "tnum": 1 }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: clock.date.toLocaleDateString(Qt.locale("ru_RU"), "ddd d MMM").replace(/\./g, "").toUpperCase()
                                    color: win.panel === "calendar" ? Theme.accent : Theme.text2
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
                            color: win.panel === "weather" ? Qt.rgba(1, 1, 1, 0.14)
                                 : wthMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                            Row {
                                id: wthRow
                                anchors.centerIn: parent
                                spacing: Theme.px(5)
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: Weather.icon
                                    size: Theme.px(16)
                                    color: win.panel === "weather" ? Theme.accent : Theme.yellow
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

                        // сейчас играет → медиа [M] (ПКМ / СКМ — пауза, колесо — громкость)
                        Rectangle {
                            visible: Media.player !== null
                            anchors.verticalCenter: parent.verticalCenter
                            width: medRow.implicitWidth + Theme.px(14)
                            height: Theme.px(32)
                            radius: Theme.px(10)
                            color: win.panel === "media" ? Qt.rgba(1, 1, 1, 0.14)
                                 : medMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05)

                            Row {
                                id: medRow
                                anchors.centerIn: parent
                                spacing: Theme.px(6)
                                ClippingRectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.px(20); height: width
                                    radius: Theme.px(5)
                                    color: Theme.pink
                                    Icon { anchors.centerIn: parent; name: "music_note"; size: Theme.px(12) }
                                    Image {
                                        anchors.fill: parent
                                        source: Media.player?.trackArtUrl ?? ""
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize: Qt.size(64, 64)
                                        visible: status === Image.Ready
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, Theme.px(100))
                                    elide: Text.ElideRight
                                    text: Media.player?.trackTitle || Media.player?.identity || ""
                                    color: win.panel === "media" ? Theme.accent : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(12)
                                    font.weight: Font.Medium
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
                                        if (Media.player && Media.player.canTogglePlaying) Media.player.togglePlaying();
                                    } else {
                                        win.openPanel("media");
                                    }
                                }
                                onWheel: w => {
                                    Audio.step(w.angleDelta.y > 0 ? 0.03 : -0.03);
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

                        StripDivider { visible: Apps.pins.length > 0 }

                        // закреплённые приложения (ЛКМ — запуск, ПКМ — открепить)
                        Row {
                            visible: Apps.pins.length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(8)
                            Repeater {
                                model: Apps.pins
                                IconImage {
                                    id: pin
                                    required property var modelData
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: Theme.px(20)
                                    source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                    scale: pinMa.pressed ? 0.85 : pinMa.containsMouse ? 1.12 : 1
                                    Behavior on scale { Spring {} }
                                    MouseArea {
                                        id: pinMa
                                        anchors.fill: parent
                                        anchors.margins: -Theme.px(3)
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                Apps.unpin(pin.modelData.id);
                                            } else {
                                                Apps.launch(pin.modelData);
                                                win.collapse();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // РЯД 2: Док-панель вкладок и инструментов (колесо мыши листает вкладки, клавиши 1..0/-)
                    Rectangle {
                        id: dockBar
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: dockInner.implicitWidth + Theme.px(16)
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
                                    id: dBtn
                                    required property var modelData
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: modelData.key === "notifications" && Notifs.dnd ? "notifications_off"
                                        : modelData.key === "mixer" && Audio.muted ? "volume_off"
                                        : modelData.icon
                                    label: modelData.label
                                    hint: modelData.hint
                                    active: win.panel === modelData.key
                                    badge: (modelData.key === "notifications" && Notifs.unread > 0 && !Notifs.dnd)
                                    tint: modelData.key === "recorder" && Recorder.recording ? Theme.red
                                        : modelData.key === "timer" && Timers.running ? Theme.orange
                                        : modelData.key === "mixer" && Audio.muted ? Theme.red
                                        : modelData.key === "notifications" && Notifs.dnd ? Theme.purple
                                        : Theme.text
                                    onHoveredChanged: {
                                        if (hovered) win.hoveredHint = modelData.label + " [" + modelData.hint + "]";
                                        else if (win.hoveredHint.indexOf(modelData.label) === 0) win.hoveredHint = "";
                                    }
                                    onClicked: win.openPanel(modelData.key)
                                    onRightClicked: win.handleRightClick(modelData.key)
                                }
                            }

                            StripDivider { height: Theme.px(16) }

                            // Плашка подсказки активной вкладки / хоткея
                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(116)
                                height: Theme.px(26)

                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - Theme.px(8)
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: {
                                        if (win.hoveredHint !== "") return win.hoveredHint;
                                        for (const it of win.dockItems) {
                                            if (it.key === win.panel) return it.label + " [" + it.hint + "]";
                                        }
                                        if (win.panel === "calendar") return "Календарь [C]";
                                        if (win.panel === "weather") return "Погода [W]";
                                        if (win.panel === "media") return "Медиа [M]";
                                        return "Tab · [1–0]";
                                    }
                                    color: win.hoveredHint !== "" || win.panel !== "" ? Theme.text2 : Theme.text3
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(11)
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                // ── Панель ──
                Item {
                    id: panelArea
                    anchors.top: strip.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: win.panelW
                    height: panelLoader.item ? panelLoader.item.implicitHeight : 0
                    opacity: win.panel !== "" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: win.panel !== "" ? Theme.fadeIn : Theme.fadeOut } }

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
                            if (item.wantsKeyboard) item.forceActiveFocus();
                            else body.forceActiveFocus();
                        }
                        // каждая новая панель появляется с лёгким пружинным подъёмом
                        ParallelAnimation {
                            id: appear
                            NumberAnimation { target: panelLoader; property: "opacity"; from: 0; to: 1; duration: Theme.fadeIn; easing.type: Easing.OutCubic }
                            SpringAnimation { target: panelLoader; property: "scale"; from: 0.96; to: 1; spring: Theme.springK; damping: Theme.springDamp; epsilon: 0.002 }
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
