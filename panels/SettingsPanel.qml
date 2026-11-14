import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.services
import qs.components

// Settings panel and Control Center.
// Categorized into 3 compact tabs:
//   1: Notch & UI (Notch indicators, behavior, scale, font size, searchable font dropdown)
//   2: Controls (Audio output sinks, Mic mute, Brightness, Night light, DND, Game mode, Keep awake)
//   3: System (User/Host, Uptime, IP info, Screenshots, Quick app launchers)
// Hotkeys:
//   1 / 2 / 3 — Switch tabs
//   N — Night Light, D — Do Not Disturb, G — Game Mode, A — Keep Awake,
//   M — Mic Mute, S — Region Screenshot, L — Lock Screen, R — Reload Hyprland,
//   ← / → — Brightness.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property bool wantsTextInput: fontDropdownOpen && fontSearchInput.activeFocus

    implicitWidth: Theme.px(440)
    implicitHeight: Theme.px(390)

    property int activeTab: 0 // 0: Notch & UI, 1: Controls, 2: System

    // ── Font Selector State ──
    property bool fontDropdownOpen: false
    property string fontQuery: ""
    property var allFonts: []
    readonly property var filteredFonts: {
        if (!fontQuery.trim().length) return allFonts;
        const q = fontQuery.trim().toLowerCase();
        return allFonts.filter(f => f.toLowerCase().indexOf(q) !== -1);
    }

    // ── Toggle states (backed by global SysToggles & Audio singletons) ──
    readonly property bool nightLight: SysToggles.nightLight
    readonly property int nightTemp: SysToggles.nightTemp
    readonly property bool keepAwake: SysToggles.keepAwake
    readonly property bool gameMode: SysToggles.gameMode
    property real brightness: 0.8

    // Wired network (LAN)
    property string lanIp: ""
    property string lanInterface: "enp34s0"
    property bool ipCopied: false

    // Audio sink dropdown menu
    property bool audioMenuOpen: false
    readonly property var sinks: Pipewire.nodes ? Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio) : []

    // User and system
    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property string hostName: Quickshell.env("HOSTNAME") || "archlinux"
    property string uptimeStr: "Uptime: ..."

    readonly property PwNode defaultSource: Audio.source
    readonly property bool micMuted: Audio.micMuted

    PwObjectTracker { objects: (root.defaultSource ? [root.defaultSource] : []).concat(root.sinks) }

    Component.onCompleted: {
        refreshHardwareStatus();
        initFonts();
    }

    Timer {
        id: statusPoller
        interval: 10000
        running: root.visible
        repeat: true
        onTriggered: root.refreshHardwareStatus()
    }

    Timer {
        id: ipCopiedTimer
        interval: 1800
        onTriggered: root.ipCopied = false
    }

    function initFonts() {
        const raw = Qt.fontFamilies();
        const map = {};
        const list = [];
        const popular = [
            "SF Pro Rounded", "SF Pro Display", "Inter", "Roboto",
            "Cantarell", "Adwaita Sans", "Ubuntu", "DejaVu Sans",
            "JetBrains Mono", "Fira Code", "Noto Sans"
        ];
        for (let i = 0; i < popular.length; i++) {
            const p = popular[i];
            if (raw.indexOf(p) !== -1) {
                map[p] = true;
                list.push(p);
            }
        }
        const rest = [];
        for (let i = 0; i < raw.length; i++) {
            const f = raw[i];
            if (!map[f] && f.indexOf("@") === -1 && f.indexOf(".") === -1) {
                map[f] = true;
                rest.push(f);
            }
        }
        rest.sort();
        allFonts = list.concat(rest);
    }

    function refreshHardwareStatus() {
        lanProc.running = false;
        lanProc.running = true;
        uptimeProc.running = false;
        uptimeProc.running = true;
    }

    Process {
        id: lanProc
        command: ["sh", "-c", "ip -4 -brief addr show scope global 2>/dev/null | awk '$1 ~ /^en|^eth|^wl/ {print $1, $3}' | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                if (parts.length >= 2) {
                    root.lanInterface = parts[0];
                    root.lanIp = parts[1].split("/")[0];
                } else if (parts.length === 1 && parts[0] !== "") {
                    root.lanIp = parts[0].split("/")[0];
                }
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p 2>/dev/null || uptime | sed 's/.*up \\([^,]*\\), .*/\\1/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out) root.uptimeStr = out;
            }
        }
    }

    function focusInput() {
        if (fontDropdownOpen) fontSearchInput.forceActiveFocus();
        else root.forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (fontDropdownOpen) {
            if (event.key === Qt.Key_Escape) {
                fontDropdownOpen = false;
                event.accepted = true;
                return;
            }
            return;
        }

        const t = (event.text || "").toLowerCase();
        if (event.key === Qt.Key_1) { activeTab = 0; event.accepted = true; }
        else if (event.key === Qt.Key_2) { activeTab = 1; event.accepted = true; }
        else if (event.key === Qt.Key_3) { activeTab = 2; event.accepted = true; }
        else if (event.key === Qt.Key_N || t === "n" || t === "т") { toggleNightLight(); event.accepted = true; }
        else if (event.key === Qt.Key_D || t === "d" || t === "в") { Notifs.dnd = !Notifs.dnd; event.accepted = true; }
        else if (event.key === Qt.Key_A || t === "a" || t === "ф") { toggleKeepAwake(); event.accepted = true; }
        else if (event.key === Qt.Key_G || t === "g" || t === "п") { toggleGameMode(); event.accepted = true; }
        else if (event.key === Qt.Key_M || t === "m" || t === "ь") { toggleMic(); event.accepted = true; }
        else if (event.key === Qt.Key_S || t === "s" || t === "ы") { takeScreenshotRegion(); event.accepted = true; }
        else if (event.key === Qt.Key_L || t === "l" || t === "д") { lockScreen(); event.accepted = true; }
        else if (event.key === Qt.Key_R || t === "r" || t === "к") { reloadHyprland(); event.accepted = true; }
        else if (event.key === Qt.Key_Left) {
            brightness = Math.max(0.05, brightness - 0.05);
            brightDebounce.restart();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            brightness = Math.min(1.0, brightness + 0.05);
            brightDebounce.restart();
            event.accepted = true;
        }
    }

    function cleanSinkName(n) {
        if (!n) return "Audio Output";
        let s = n.description || n.nickname || n.name || "";
        s = s.replace(/Analog Stereo/gi, "Speakers / Line Out")
             .replace(/Digital Stereo \(HDMI.*?\)/gi, "HDMI Monitor")
             .replace(/Audio Controller/gi, "")
             .replace(/Built-in Audio/gi, "Built-in Audio");
        return s.trim() || "Audio Output";
    }

    function sinkIcon(n) {
        if (!n) return "volume_up";
        const name = ((n.description || "") + " " + (n.name || "")).toLowerCase();
        if (name.includes("headphone") || name.includes("headset")) return "headphones";
        if (name.includes("hdmi") || name.includes("displayport") || name.includes("tv")) return "tv";
        if (name.includes("speaker")) return "speaker";
        return "volume_up";
    }

    function isDefaultSink(n) {
        if (!n || !Audio.sink) return false;
        return n.id === Audio.sink.id || n.name === Audio.sink.name;
    }

    function copyLanIp() {
        const ip = root.lanIp !== "" ? root.lanIp : "127.0.0.1";
        Quickshell.execDetached(["wl-copy", "--", ip]);
        root.ipCopied = true;
        ipCopiedTimer.restart();
    }

    function openUserTerminal() {
        Quickshell.execDetached(["sh", "-c", "TERM_CMD=$(grep -oP 'terminal\\s*=\\s*\"\\K[^\"]+' ~/.config/hypr/variables.lua 2>/dev/null || true); [ -z \"$TERM_CMD\" ] && TERM_CMD=\"$TERMINAL\"; [ -z \"$TERM_CMD\" ] && command -v foot >/dev/null 2>&1 && TERM_CMD=\"foot\"; [ -z \"$TERM_CMD\" ] && command -v kitty >/dev/null 2>&1 && TERM_CMD=\"kitty\"; [ -z \"$TERM_CMD\" ] && command -v alacritty >/dev/null 2>&1 && TERM_CMD=\"alacritty\"; [ -z \"$TERM_CMD\" ] && TERM_CMD=\"xdg-terminal-exec\"; exec $TERM_CMD"]);
    }

    function openBtop() {
        Quickshell.execDetached(["sh", "-c", "TERM_CMD=$(grep -oP 'terminal\\s*=\\s*\"\\K[^\"]+' ~/.config/hypr/variables.lua 2>/dev/null || true); [ -z \"$TERM_CMD\" ] && TERM_CMD=\"$TERMINAL\"; [ -z \"$TERM_CMD\" ] && command -v foot >/dev/null 2>&1 && TERM_CMD=\"foot\"; [ -z \"$TERM_CMD\" ] && command -v kitty >/dev/null 2>&1 && TERM_CMD=\"kitty\"; [ -z \"$TERM_CMD\" ] && command -v alacritty >/dev/null 2>&1 && TERM_CMD=\"alacritty\"; [ -z \"$TERM_CMD\" ] && TERM_CMD=\"xdg-terminal-exec\"; exec $TERM_CMD -e btop"]);
    }

    function toggleNightLight() { SysToggles.toggleNightLight(); }
    function toggleKeepAwake() { SysToggles.toggleKeepAwake(); }
    function toggleGameMode() { SysToggles.toggleGameMode(); }
    function toggleMic() { Audio.toggleMic(); }

    function takeScreenshotRegion() {
        if (host) host.collapse();
        Quickshell.execDetached(["sh", "-c", "sleep 0.25 && REG=$(slurp </dev/null) && [ -n \"$REG\" ] && grim -g \"$REG\" - | wl-copy && notify-send -a 'Dynamic Notch' 'Screenshot' 'Selected region copied to clipboard'"]);
    }

    function takeScreenshotFull() {
        if (host) host.collapse();
        Quickshell.execDetached(["sh", "-c", "sleep 0.25 && grim - | wl-copy && notify-send -a 'Dynamic Notch' 'Screen Screenshot' 'Full display snapshot copied to clipboard'"]);
    }

    function lockScreen() {
        if (host) host.collapse();
        Quickshell.execDetached(["sh", "-c", "hyprlock >/dev/null 2>&1 || loginctl lock-session >/dev/null 2>&1"]);
    }

    function reloadHyprland() {
        Quickshell.execDetached(["sh", "-c", "hyprctl reload && notify-send -a 'Dynamic Notch' 'Hyprland' 'Configuration reloaded'"]);
    }

    Timer {
        id: brightDebounce
        interval: 300
        onTriggered: {
            const val = Math.round(root.brightness * 100);
            Quickshell.execDetached(["sh", "-c", "command -v brightnessctl >/dev/null 2>&1 && brightnessctl set " + val + "% >/dev/null 2>&1; command -v ddcutil >/dev/null 2>&1 && ddcutil setvcp 10 " + val + " --noverify >/dev/null 2>&1 &"]);
        }
    }

    // ── Main UI Layout ──
    Column {
        anchors.fill: parent
        spacing: Theme.px(8)

        // ── Top Segmented Tab Switcher [Notch & UI | Controls | System] ──
        Rectangle {
            width: parent.width
            height: Theme.px(32)
            radius: Theme.px(10)
            color: Qt.rgba(1, 1, 1, 0.05)

            Row {
                anchors.fill: parent
                anchors.margins: Theme.px(3)
                spacing: Theme.px(4)

                Repeater {
                    model: [
                        { name: "Notch & UI", icon: "tune" },
                        { name: "Controls", icon: "tune" },
                        { name: "System", icon: "desktop_windows" }
                    ]

                    Rectangle {
                        id: tabItem
                        required property var modelData
                        required property int index
                        width: (parent.width - Theme.px(8)) / 3
                        height: parent.height
                        radius: Theme.px(8)
                        color: root.activeTab === index ? Theme.cardHover : (tabMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.transparent)
                        border.width: root.activeTab === index ? 1 : 0
                        border.color: Theme.controlFill

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.px(5)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: tabItem.modelData.icon
                                size: Theme.px(13)
                                color: root.activeTab === tabItem.index ? Theme.controlFill : Theme.text2
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tabItem.modelData.name
                                color: root.activeTab === tabItem.index ? Theme.text : Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: root.activeTab === tabItem.index ? Font.DemiBold : Font.Normal
                            }
                        }

                        MouseArea {
                            id: tabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTab = tabItem.index
                        }
                    }
                }
            }
        }

        // ── Tab 0: Notch & UI ──
        Flickable {
            id: tabNotch
            visible: root.activeTab === 0
            width: parent.width
            height: Theme.px(350)
            contentWidth: width
            contentHeight: tabNotchCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: tabNotchCol
                width: parent.width
                spacing: Theme.px(8)

                // Card 1: Notch Indicators & Behavior
                Rectangle {
                    width: parent.width
                height: Theme.px(164)
                radius: Theme.px(14)
                color: Theme.card

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.px(10)
                    spacing: Theme.px(8)

                    Text {
                        text: "Compact Notch Indicator"
                        color: Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(9)
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                    }

                    // 4-way indicator switcher
                    Row {
                        width: parent.width
                        spacing: Theme.px(6)

                        Repeater {
                            model: [
                                { id: "weather", name: "Weather", icon: "cloud" },
                                { id: "cpu",     name: "CPU / Temp", icon: "memory" },
                                { id: "net",     name: "LAN Net", icon: "swap_vert" },
                                { id: "none",    name: "Hide", icon: "visibility_off" }
                            ]

                            Rectangle {
                                id: indBtn
                                required property var modelData
                                width: (parent.width - Theme.px(18)) / 4
                                height: Theme.px(26)
                                radius: Theme.px(7)
                                readonly property bool active: IslandPrefs.compactWidget === modelData.id
                                color: active ? Theme.controlFill : (indMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.05))

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.px(4)
                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: indBtn.modelData.icon
                                        size: Theme.px(12)
                                        color: indBtn.active ? "#000000" : Theme.text2
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: indBtn.modelData.name
                                        color: indBtn.active ? "#000000" : Theme.text2
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.px(9)
                                        font.weight: indBtn.active ? Font.Bold : Font.Normal
                                    }
                                }

                                MouseArea {
                                    id: indMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: IslandPrefs.compactWidget = indBtn.modelData.id
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.divider }

                    // Toggles: Clock Seconds, Auto Collapse, Hide in Games
                    Item {
                        width: parent.width
                        height: Theme.px(22)
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Clock Seconds (HH:MM:SS)"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(34); height: Theme.px(18); radius: height / 2
                            color: IslandPrefs.showSeconds ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.15)
                            Rectangle {
                                width: Theme.px(14); height: width; radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: IslandPrefs.showSeconds ? (parent.width - width - Theme.px(2)) : Theme.px(2)
                                color: IslandPrefs.showSeconds ? "#000000" : Theme.text
                                Behavior on x { Spring { epsilon: 0.1 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandPrefs.showSeconds = !IslandPrefs.showSeconds
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: Theme.px(22)
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Auto Collapse When Cursor Leaves"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(34); height: Theme.px(18); radius: height / 2
                            color: IslandPrefs.autoCollapse ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.15)
                            Rectangle {
                                width: Theme.px(14); height: width; radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: IslandPrefs.autoCollapse ? (parent.width - width - Theme.px(2)) : Theme.px(2)
                                color: IslandPrefs.autoCollapse ? "#000000" : Theme.text
                                Behavior on x { Spring { epsilon: 0.1 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandPrefs.autoCollapse = !IslandPrefs.autoCollapse
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: Theme.px(22)
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Hide Notch in Fullscreen / Games"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(34); height: Theme.px(18); radius: height / 2
                            color: IslandPrefs.hideInGames ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.15)
                            Rectangle {
                                width: Theme.px(14); height: width; radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: IslandPrefs.hideInGames ? (parent.width - width - Theme.px(2)) : Theme.px(2)
                                color: IslandPrefs.hideInGames ? "#000000" : Theme.text
                                Behavior on x { Spring { epsilon: 0.1 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandPrefs.hideInGames = !IslandPrefs.hideInGames
                            }
                        }
                    }
                }
            }

            // Card 2: Scaling & Typography
            Rectangle {
                width: parent.width
                height: Theme.px(176)
                radius: Theme.px(14)
                color: Theme.card

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.px(10)
                    spacing: Theme.px(7)

                    // ── Setting: Interface Scale ──
                    Item {
                        width: parent.width
                        height: Theme.px(18)

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(6)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "aspect_ratio"
                                size: Theme.px(14)
                                color: Theme.text
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Interface Scale"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.px(18)
                            width: scaleValText.implicitWidth + Theme.px(10)
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.1)

                            Text {
                                id: scaleValText
                                anchors.centerIn: parent
                                text: Math.round(IslandPrefs.uiScale * 100) + "%"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                                font.weight: Font.Bold
                                font.features: { "tnum": 1 }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: Theme.px(24)

                        Bar {
                            anchors.left: parent.left
                            anchors.right: scaleResetBtn.left
                            anchors.rightMargin: Theme.px(8)
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.px(7)
                            value: Math.max(0, Math.min(1, (IslandPrefs.uiScale - 0.8) / 0.7))
                            tint: Theme.controlFill
                            interactive: true
                            onMoved: v => {
                                const raw = 0.8 + v * 0.7;
                                const stepped = Math.round(raw * 20) / 20;
                                IslandPrefs.setScale(stepped);
                            }
                        }

                        Rectangle {
                            id: scaleResetBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(54)
                            height: Theme.px(22)
                            radius: Theme.px(5)
                            color: scaleResetMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "Reset"
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                            }
                            MouseArea {
                                id: scaleResetMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandPrefs.setScale(1.15)
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.divider }

                    // ── Setting: Base Font Size ──
                    Item {
                        width: parent.width
                        height: Theme.px(18)

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(6)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "format_size"
                                size: Theme.px(14)
                                color: Theme.text
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Base Font Size"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.px(18)
                            width: fontValText.implicitWidth + Theme.px(10)
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.1)

                            Text {
                                id: fontValText
                                anchors.centerIn: parent
                                text: IslandPrefs.fontSize + " pt"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                                font.weight: Font.Bold
                                font.features: { "tnum": 1 }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: Theme.px(24)

                        Bar {
                            anchors.left: parent.left
                            anchors.right: fontResetBtn.left
                            anchors.rightMargin: Theme.px(8)
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.px(7)
                            value: Math.max(0, Math.min(1, (IslandPrefs.fontSize - 10) / 8))
                            tint: Theme.controlFill
                            interactive: true
                            onMoved: v => IslandPrefs.setFontSize(Math.round(10 + v * 8))
                        }

                        Rectangle {
                            id: fontResetBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(54)
                            height: Theme.px(22)
                            radius: Theme.px(5)
                            color: fontResetMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "Reset"
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                            }
                            MouseArea {
                                id: fontResetMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandPrefs.setFontSize(13)
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.divider }

                    // ── Setting: Font Family (Dropdown Trigger) ──
                    Item {
                        width: parent.width
                        height: Theme.px(26)

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(6)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "font_download"
                                size: Theme.px(14)
                                color: Theme.text
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Font Family"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.px(24)
                            width: fontPickRow.implicitWidth + Theme.px(14)
                            radius: Theme.px(6)
                            color: fontPickMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            border.color: Theme.controlFill

                            Row {
                                id: fontPickRow
                                anchors.centerIn: parent
                                spacing: Theme.px(5)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: IslandPrefs.fontFamily
                                    color: Theme.text
                                    font.family: IslandPrefs.fontFamily
                                    font.pixelSize: Theme.px(10)
                                    font.weight: Font.DemiBold
                                }
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "expand_more"
                                    size: Theme.px(13)
                                    color: Theme.text2
                                }
                            }

                            MouseArea {
                                id: fontPickMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.fontQuery = "";
                                    root.fontDropdownOpen = true;
                                    focusTimer.restart();
                                }
                            }
                        }
                    }
                }
            }

            // Card 3: Live Activity Wings
            Rectangle {
                width: parent.width
                height: wingsCol.implicitHeight + Theme.px(20)
                radius: Theme.px(14)
                color: Theme.card

                Column {
                    id: wingsCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.px(10)
                    spacing: Theme.px(8)

                    Item {
                        width: parent.width
                        height: Theme.px(22)
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Live Activity Wings (Left & Right)"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: Font.DemiBold
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(34); height: Theme.px(18); radius: height / 2
                            color: IslandPrefs.liveWingsEnabled ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.15)
                            Rectangle {
                                width: Theme.px(14); height: width; radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: IslandPrefs.liveWingsEnabled ? (parent.width - width - Theme.px(2)) : Theme.px(2)
                                color: IslandPrefs.liveWingsEnabled ? "#000000" : Theme.text
                                Behavior on x { Spring { epsilon: 0.1 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandPrefs.togglePref("liveWingsEnabled")
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.px(6)
                        opacity: IslandPrefs.liveWingsEnabled ? 1.0 : 0.45
                        enabled: IslandPrefs.liveWingsEnabled

                        Repeater {
                            model: [
                                { id: "inline", name: "Inside Notch", icon: "splitscreen_left" },
                                { id: "duo",    name: "Duo Circles",  icon: "hdr_strong" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: IslandPrefs.liveActivityStyle === modelData.id
                                width: (parent.width - Theme.px(6)) / 2
                                height: Theme.px(30)
                                radius: Theme.px(9)
                                color: active ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.05)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.px(6)
                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: modelData.icon
                                        size: Theme.px(13)
                                        color: active ? "#000000" : Theme.textDim
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name
                                        color: active ? "#000000" : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.px(10.5)
                                        font.weight: active ? Font.DemiBold : Font.Medium
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: IslandPrefs.setLiveActivityStyle(modelData.id)
                                }
                            }
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: Theme.px(6)
                        rowSpacing: Theme.px(6)
                        opacity: IslandPrefs.liveWingsEnabled ? 1.0 : 0.45
                        enabled: IslandPrefs.liveWingsEnabled

                        Repeater {
                            model: [
                                { key: "liveMediaEnabled",   name: "Media Art & Wave", icon: "music_note" },
                                { key: "liveMediaShowTitle", name: "Track Title",      icon: "title" },
                                { key: "liveClipboardPulse", name: "Clipboard OSD",    icon: "content_paste" },
                                { key: "liveMicPrivacy",     name: "Mic Privacy",      icon: "mic" },
                                { key: "liveThermalAlert",   name: "Thermal / Load",   icon: "local_fire_department" },
                                { key: "liveSystemModes",    name: "System Modes",     icon: "coffee" },
                                { key: "liveAudioMuted",     name: "Muted Output",     icon: "volume_off" },
                                { key: "liveCapsLock",       name: "Caps Lock OSD",    icon: "keyboard_capslock" }
                            ]

                            Rectangle {
                                id: wingOpt
                                required property var modelData
                                width: (parent.width - Theme.px(6)) / 2
                                height: Theme.px(26)
                                radius: Theme.px(7)
                                readonly property bool active: !!IslandPrefs[modelData.key]
                                color: active ? Theme.controlFill : (wingOptMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.05))

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.px(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.px(6)

                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: wingOpt.modelData.icon
                                        size: Theme.px(12)
                                        color: wingOpt.active ? "#000000" : Theme.text2
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: wingOpt.modelData.name
                                        color: wingOpt.active ? "#000000" : Theme.text2
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.px(10)
                                        font.weight: wingOpt.active ? Font.Bold : Font.Normal
                                    }
                                }

                                MouseArea {
                                    id: wingOptMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: IslandPrefs.togglePref(wingOpt.modelData.key)
                                }
                            }
                        }
                    }
                }
            }
            }
        }

        // ── Tab 1: Controls & Audio ──
        Column {
            id: tabControls
            visible: root.activeTab === 1
            width: parent.width
            spacing: Theme.px(8)

            // Card 1: Audio Output & Mic
            Rectangle {
                width: parent.width
                height: root.audioMenuOpen ? Theme.px(180) : Theme.px(104)
                radius: Theme.px(14)
                color: Theme.card
                clip: true
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.px(10)
                    spacing: Theme.px(8)

                    Item {
                        width: parent.width
                        height: Theme.px(28)

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(8)

                            Rectangle {
                                width: Theme.px(28); height: width; radius: width / 2
                                color: Qt.rgba(1, 1, 1, 0.1)
                                Icon {
                                    anchors.centerIn: parent
                                    name: root.sinkIcon(Audio.sink)
                                    size: Theme.px(15)
                                    color: Theme.text
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    text: root.cleanSinkName(Audio.sink)
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(11)
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    width: Theme.px(200)
                                }
                                Text {
                                    text: Math.round(Audio.volume * 100) + "% Output Volume"
                                    color: Theme.text3
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(9)
                                }
                            }
                        }

                        // Chevron to toggle sink list
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(26); height: width; radius: width / 2
                            color: sinkChevronMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)

                            Icon {
                                anchors.centerIn: parent
                                name: "expand_more"
                                size: Theme.px(15)
                                color: Theme.text2
                                rotation: root.audioMenuOpen ? 180 : 0
                                Behavior on rotation { NumberAnimation { duration: 160 } }
                            }
                            MouseArea {
                                id: sinkChevronMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.audioMenuOpen = !root.audioMenuOpen
                            }
                        }
                    }

                    // Sink List when open
                    ListView {
                        visible: root.audioMenuOpen
                        width: parent.width
                        height: Theme.px(70)
                        clip: true
                        model: root.sinks
                        spacing: Theme.px(3)
                        delegate: Rectangle {
                            id: sinkItem
                            required property var modelData
                            width: parent.width
                            height: Theme.px(24)
                            radius: Theme.px(6)
                            readonly property bool isCurrent: root.isDefaultSink(modelData)
                            color: isCurrent ? Qt.rgba(1, 1, 1, 0.12) : (sinkItemMa.containsMouse ? Theme.cardHover : Qt.transparent)

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.px(6)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.px(6)

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: root.sinkIcon(sinkItem.modelData)
                                    size: Theme.px(12)
                                    color: sinkItem.isCurrent ? Theme.controlFill : Theme.text2
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.cleanSinkName(sinkItem.modelData)
                                    color: sinkItem.isCurrent ? Theme.text : Theme.text2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(10)
                                    font.weight: sinkItem.isCurrent ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                    width: Theme.px(360)
                                }
                            }

                            MouseArea {
                                id: sinkItemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Audio.setSink(sinkItem.modelData);
                                    root.audioMenuOpen = false;
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.divider }

                    // Quick Audio Action Buttons
                    Row {
                        width: parent.width
                        spacing: Theme.px(6)

                        // Mic Toggle Button
                        Rectangle {
                            width: (parent.width - Theme.px(6)) / 2
                            height: Theme.px(28)
                            radius: Theme.px(7)
                            color: root.micMuted ? Qt.rgba(1, 0.2, 0.2, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            border.color: root.micMuted ? Theme.alert : Qt.rgba(1, 1, 1, 0.12)

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(5)
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: root.micMuted ? "mic_off" : "mic"
                                    size: Theme.px(14)
                                    color: root.micMuted ? Theme.alert : Theme.text
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.micMuted ? "Mic Muted [M]" : "Mic Active [M]"
                                    color: root.micMuted ? Theme.alert : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(10)
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleMic()
                            }
                        }

                        // Pavucontrol Button
                        Rectangle {
                            width: (parent.width - Theme.px(6)) / 2
                            height: Theme.px(28)
                            radius: Theme.px(7)
                            color: pavuMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(5)
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "tune"
                                    size: Theme.px(14)
                                    color: Theme.text
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Volume Mixer"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(10)
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                id: pavuMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["pavucontrol"])
                            }
                        }
                    }
                }
            }

            // Card 2: Display & Lighting
            Rectangle {
                width: parent.width
                height: Theme.px(130)
                radius: Theme.px(14)
                color: Theme.card

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.px(10)
                    spacing: Theme.px(8)

                    // Brightness slider
                    Item {
                        width: parent.width
                        height: Theme.px(18)

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(6)
                            Icon { name: "brightness_6"; size: Theme.px(14); color: Theme.text }
                            Text {
                                text: "Display Brightness"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(root.brightness * 100) + "%"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                        }
                    }

                    Bar {
                        width: parent.width
                        height: Theme.px(8)
                        value: root.brightness
                        tint: Theme.controlFill
                        interactive: true
                        onMoved: v => {
                            root.brightness = v;
                            brightDebounce.restart();
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.divider }

                    // Night Light & DND
                    Row {
                        width: parent.width
                        spacing: Theme.px(8)

                        Rectangle {
                            width: (parent.width - Theme.px(8)) / 2
                            height: Theme.px(34)
                            radius: Theme.px(8)
                            color: root.nightLight ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.08)

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(6)
                                Icon {
                                    name: "bedtime"
                                    size: Theme.px(15)
                                    color: root.nightLight ? "#000000" : Theme.text
                                }
                                Text {
                                    text: root.nightLight ? "Night Light [N]" : "Night Light [N]"
                                    color: root.nightLight ? "#000000" : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(10)
                                    font.weight: Font.Medium
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleNightLight()
                            }
                        }

                        Rectangle {
                            width: (parent.width - Theme.px(8)) / 2
                            height: Theme.px(34)
                            radius: Theme.px(8)
                            color: Notifs.dnd ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.08)

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(6)
                                Icon {
                                    name: "do_not_disturb_on"
                                    size: Theme.px(15)
                                    color: Notifs.dnd ? "#000000" : Theme.text
                                }
                                Text {
                                    text: Notifs.dnd ? "DND Active [D]" : "Do Not Disturb [D]"
                                    color: Notifs.dnd ? "#000000" : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(10)
                                    font.weight: Font.Medium
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.dnd = !Notifs.dnd
                            }
                        }
                    }
                }
            }

            // Card 3: Session & Modes
            Row {
                width: parent.width
                spacing: Theme.px(8)

                Rectangle {
                    width: (parent.width - Theme.px(16)) / 3
                    height: Theme.px(50)
                    radius: Theme.px(12)
                    color: root.gameMode ? Theme.controlFill : Theme.card

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.px(3)
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "sports_esports"
                            size: Theme.px(16)
                            color: root.gameMode ? "#000000" : Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Game [G]"
                            color: root.gameMode ? "#000000" : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(10)
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleGameMode()
                    }
                }

                Rectangle {
                    width: (parent.width - Theme.px(16)) / 3
                    height: Theme.px(50)
                    radius: Theme.px(12)
                    color: root.keepAwake ? Theme.controlFill : Theme.card

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.px(3)
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "coffee"
                            size: Theme.px(16)
                            color: root.keepAwake ? "#000000" : Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Awake [A]"
                            color: root.keepAwake ? "#000000" : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(10)
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleKeepAwake()
                    }
                }

                Rectangle {
                    width: (parent.width - Theme.px(16)) / 3
                    height: Theme.px(50)
                    radius: Theme.px(12)
                    color: Theme.card

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.px(3)
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "videocam"
                            size: Theme.px(16)
                            color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Record"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(10)
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.host) root.host.openPanel("recorder");
                        }
                    }
                }
            }
        }

        // ── Tab 2: System & Tools ──
        Column {
            id: tabSystem
            visible: root.activeTab === 2
            width: parent.width
            spacing: Theme.px(8)

            // Card 1: User & System Header
            Rectangle {
                width: parent.width
                height: Theme.px(64)
                radius: Theme.px(14)
                color: Theme.card

                Item {
                    anchors.fill: parent
                    anchors.margins: Theme.px(10)

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(10)

                        Rectangle {
                            width: Theme.px(36); height: width; radius: width / 2
                            color: Qt.rgba(1, 1, 1, 0.1)
                            Icon {
                                anchors.centerIn: parent
                                name: "person"
                                size: Theme.px(20)
                                color: Theme.text
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(2)

                            Text {
                                text: root.userName + " @ " + root.hostName
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.Bold
                            }

                            Text {
                                text: root.uptimeStr
                                color: Theme.text3
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                            }
                        }
                    }

                    // Reload & Lock Buttons
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(6)

                        Rectangle {
                            width: Theme.px(32); height: width; radius: width / 2
                            color: reloadMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)
                            Icon {
                                anchors.centerIn: parent
                                name: "refresh"
                                size: Theme.px(16)
                                color: Theme.text
                            }
                            MouseArea {
                                id: reloadMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.reloadHyprland()
                            }
                        }

                        Rectangle {
                            width: Theme.px(32); height: width; radius: width / 2
                            color: lockMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)
                            Icon {
                                anchors.centerIn: parent
                                name: "lock"
                                size: Theme.px(16)
                                color: Theme.text
                            }
                            MouseArea {
                                id: lockMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.lockScreen()
                            }
                        }
                    }
                }
            }

            // Card 2: Network IP Card
            Rectangle {
                width: parent.width
                height: Theme.px(44)
                radius: Theme.px(12)
                color: Theme.card

                Item {
                    anchors.fill: parent
                    anchors.margins: Theme.px(10)

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(8)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "lan"
                            size: Theme.px(16)
                            color: Theme.text
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: "LAN IP (" + (root.lanInterface || "network") + ")"
                                color: Theme.text3
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(9)
                            }
                            Text {
                                text: root.lanIp !== "" ? root.lanIp : "127.0.0.1"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: Theme.px(24)
                        width: copyIpText.implicitWidth + Theme.px(14)
                        radius: Theme.px(6)
                        color: root.ipCopied ? Theme.controlFill : (copyIpMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08))

                        Text {
                            id: copyIpText
                            anchors.centerIn: parent
                            text: root.ipCopied ? "Copied!" : "Copy IP"
                            color: root.ipCopied ? "#000000" : Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(10)
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: copyIpMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyLanIp()
                        }
                    }
                }
            }

            // Card 3: Screenshot Actions
            Rectangle {
                width: parent.width
                height: Theme.px(68)
                radius: Theme.px(12)
                color: Theme.card

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.px(10)
                    spacing: Theme.px(6)

                    Text {
                        text: "Screenshots"
                        color: Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(9)
                        font.weight: Font.Bold
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.px(8)

                        Rectangle {
                            width: (parent.width - Theme.px(8)) / 2
                            height: Theme.px(28)
                            radius: Theme.px(7)
                            color: rShotMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(5)
                                Icon { name: "crop"; size: Theme.px(13); color: Theme.text }
                                Text {
                                    text: "Region Shot [S]"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(10)
                                    font.weight: Font.Medium
                                }
                            }
                            MouseArea {
                                id: rShotMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.takeScreenshotRegion()
                            }
                        }

                        Rectangle {
                            width: (parent.width - Theme.px(8)) / 2
                            height: Theme.px(28)
                            radius: Theme.px(7)
                            color: fShotMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(5)
                                Icon { name: "fullscreen"; size: Theme.px(14); color: Theme.text }
                                Text {
                                    text: "Full Screen Shot"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(10)
                                    font.weight: Font.Medium
                                }
                            }
                            MouseArea {
                                id: fShotMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.takeScreenshotFull()
                            }
                        }
                    }
                }
            }

            // Card 4: Quick Launch Apps
            Row {
                width: parent.width
                spacing: Theme.px(8)

                Rectangle {
                    width: (parent.width - Theme.px(16)) / 3
                    height: Theme.px(36)
                    radius: Theme.px(10)
                    color: pAppMa.containsMouse ? Theme.cardHover : Theme.card

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(5)
                        Icon { name: "tune"; size: Theme.px(14); color: Theme.text }
                        Text {
                            text: "Pavucontrol"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(10)
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        id: pAppMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["pavucontrol"])
                    }
                }

                Rectangle {
                    width: (parent.width - Theme.px(16)) / 3
                    height: Theme.px(36)
                    radius: Theme.px(10)
                    color: btopMa.containsMouse ? Theme.cardHover : Theme.card

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(5)
                        Icon { name: "speed"; size: Theme.px(14); color: Theme.text }
                        Text {
                            text: "Btop"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(10)
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        id: btopMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openBtop()
                    }
                }

                Rectangle {
                    width: (parent.width - Theme.px(16)) / 3
                    height: Theme.px(36)
                    radius: Theme.px(10)
                    color: termMa.containsMouse ? Theme.cardHover : Theme.card

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(5)
                        Icon { name: "terminal"; size: Theme.px(14); color: Theme.text }
                        Text {
                            text: "Terminal"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(10)
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        id: termMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openUserTerminal()
                    }
                }
            }
        }
    }

    // ── Searchable Font Selector Dropdown Modal ──
    Rectangle {
        id: fontModal
        visible: root.fontDropdownOpen
        anchors.fill: parent
        radius: Theme.px(16)
        color: "#0F1211"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
        z: 999

        Column {
            anchors.fill: parent
            anchors.margins: Theme.px(12)
            spacing: Theme.px(8)

            // Header Row
            Item {
                width: parent.width
                height: Theme.px(28)

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(6)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "font_download"
                        size: Theme.px(15)
                        color: Theme.controlFill
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Choose Font Family"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.Bold
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(24); height: width; radius: width / 2
                    color: closeFontMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.08)

                    Icon {
                        anchors.centerIn: parent
                        name: "close"
                        size: Theme.px(13)
                        color: Theme.text2
                    }
                    MouseArea {
                        id: closeFontMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.fontDropdownOpen = false
                    }
                }
            }

            // Search Input Box
            Rectangle {
                width: parent.width
                height: Theme.px(30)
                radius: Theme.px(7)
                color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 1
                border.color: fontSearchInput.activeFocus ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.12)

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.px(8)
                    anchors.right: fontClearBtn.visible ? fontClearBtn.left : parent.right
                    anchors.rightMargin: Theme.px(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(6)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        size: Theme.px(14)
                        color: Theme.text3
                    }

                    TextInput {
                        id: fontSearchInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.px(24)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        color: Theme.text
                        selectionColor: Theme.controlFill
                        cursorDelegate: Caret {}
                        clip: true
                        onTextChanged: root.fontQuery = text

                        Text {
                            visible: fontSearchInput.text.length === 0
                            text: "Type to search installed fonts..."
                            color: Theme.text3
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(12)
                        }
                    }
                }

                Rectangle {
                    id: fontClearBtn
                    visible: fontSearchInput.text.length > 0
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.px(6)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(18); height: width; radius: width / 2
                    color: fontClearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.transparent

                    Icon {
                        anchors.centerIn: parent
                        name: "close"
                        size: Theme.px(11)
                        color: Theme.text3
                    }
                    MouseArea {
                        id: fontClearMa
                        anchors.fill: parent
                        onClicked: fontSearchInput.text = ""
                    }
                }
            }

            // Scrollable List of Fonts
            ListView {
                id: fontListView
                width: parent.width
                height: parent.height - Theme.px(74)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.filteredFonts
                spacing: Theme.px(3)

                delegate: Rectangle {
                    id: fontDelegate
                    required property string modelData
                    required property int index
                    width: fontListView.width
                    height: Theme.px(30)
                    radius: Theme.px(6)
                    readonly property bool isCurrent: IslandPrefs.fontFamily === modelData
                    color: isCurrent ? Qt.rgba(1, 1, 1, 0.14) : (fMa.containsMouse ? Theme.cardHover : Qt.transparent)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.px(10)
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.px(10)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: fontDelegate.modelData
                            color: fontDelegate.isCurrent ? Theme.controlFill : Theme.text
                            font.family: fontDelegate.modelData
                            font.pixelSize: Theme.px(12)
                            font.weight: fontDelegate.isCurrent ? Font.Bold : Font.Normal
                            elide: Text.ElideRight
                            width: parent.width - (fontDelegate.isCurrent ? Theme.px(22) : 0)
                        }

                        Icon {
                            visible: fontDelegate.isCurrent
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: Theme.px(14)
                            color: Theme.controlFill
                        }
                    }

                    MouseArea {
                        id: fMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            IslandPrefs.setFontFamily(fontDelegate.modelData);
                            root.fontDropdownOpen = false;
                        }
                    }
                }

                // Empty state if search has no results
                Column {
                    visible: root.filteredFonts.length === 0
                    anchors.centerIn: parent
                    spacing: Theme.px(4)
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "search_off"
                        size: Theme.px(22)
                        color: Theme.text3
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No fonts matching \"" + root.fontQuery + "\""
                        color: Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                    }
                }
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: fontSearchInput.forceActiveFocus()
    }
}
