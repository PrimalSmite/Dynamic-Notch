import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.services
import qs.components

// Панель настроек и системного центра управления (Control Center & Notch Settings).
// Оптимизировано для настольного ПК: проводной Ethernet (LAN), выбор аудио-выходов PipeWire (выпадающее меню),
// детальные настройки поведения динамической чёлки и дашборда.
// Горячие клавиши:
//   N — Ночной свет, D — Не беспокоить, G — Игровой режим, A — Без сна (не усыплять),
//   M — Микрофон, S — Скриншот области, L — Блокировка, R — Перезагрузка Hyprland,
//   ← / → — Яркость экрана.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true

    implicitWidth: Theme.px(420)
    implicitHeight: mainCol.implicitHeight

    // ── Состояния переключателей ──
    property bool nightLight: false
    property int nightTemp: 4200
    property bool keepAwake: false
    property bool gameMode: false
    property real brightness: 0.8

    // Проводная сеть (LAN)
    property string lanIp: ""
    property string lanInterface: "enp34s0"
    property bool ipCopied: false

    // Выпадающее меню аудиовыхода
    property bool audioMenuOpen: false
    readonly property var sinks: Pipewire.nodes ? Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio) : []

    // Пользователь и система
    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property string hostName: Quickshell.env("HOSTNAME") || "archlinux"

    readonly property PwNode defaultSource: Pipewire.defaultAudioSource
    readonly property bool micMuted: defaultSource && defaultSource.audio ? defaultSource.audio.muted : false

    PwObjectTracker { objects: (root.defaultSource ? [root.defaultSource] : []).concat(root.sinks) }

    Component.onCompleted: {
        refreshHardwareStatus();
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

    function refreshHardwareStatus() {
        lanProc.running = false;
        lanProc.running = true;
    }

    // ── Фоновые процессы опроса ──
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

    // ── Клавиатурные сокращения ──
    Keys.onPressed: event => {
        const t = (event.text || "").toLowerCase();
        if (event.key === Qt.Key_N || t === "n" || t === "т") { toggleNightLight(); event.accepted = true; }
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

    // ── Управление аудиовыходом и сетью ──
    function cleanSinkName(n) {
        if (!n) return "Аудиовыход";
        let s = n.description || n.nickname || n.name || "";
        s = s.replace(/Analog Stereo/gi, "Динамики / Line Out")
             .replace(/Digital Stereo \(HDMI.*?\)/gi, "HDMI Монитор")
             .replace(/Audio Controller/gi, "")
             .replace(/Built-in Audio/gi, "Встроенный звук");
        return s.trim() || "Аудиовыход";
    }

    function sinkIcon(n) {
        if (!n) return "volume_up";
        const name = ((n.description || "") + " " + (n.name || "")).toLowerCase();
        if (name.includes("headphone") || name.includes("headset") || name.includes("наушник")) return "headphones";
        if (name.includes("hdmi") || name.includes("displayport") || name.includes("tv")) return "tv";
        if (name.includes("speaker") || name.includes("динамик")) return "speaker";
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

    // ── Запуск терминала пользователя (по конфигурации Hyprland) ──
    function openUserTerminal() {
        Quickshell.execDetached(["sh", "-c", "TERM_CMD=$(grep -oP 'terminal\\s*=\\s*\"\\K[^\"]+' ~/.config/hypr/variables.lua 2>/dev/null || true); [ -z \"$TERM_CMD\" ] && TERM_CMD=\"$TERMINAL\"; [ -z \"$TERM_CMD\" ] && command -v foot >/dev/null 2>&1 && TERM_CMD=\"foot\"; [ -z \"$TERM_CMD\" ] && command -v kitty >/dev/null 2>&1 && TERM_CMD=\"kitty\"; [ -z \"$TERM_CMD\" ] && command -v alacritty >/dev/null 2>&1 && TERM_CMD=\"alacritty\"; [ -z \"$TERM_CMD\" ] && TERM_CMD=\"xdg-terminal-exec\"; exec $TERM_CMD"]);
    }

    function openBtop() {
        Quickshell.execDetached(["sh", "-c", "TERM_CMD=$(grep -oP 'terminal\\s*=\\s*\"\\K[^\"]+' ~/.config/hypr/variables.lua 2>/dev/null || true); [ -z \"$TERM_CMD\" ] && TERM_CMD=\"$TERMINAL\"; [ -z \"$TERM_CMD\" ] && command -v foot >/dev/null 2>&1 && TERM_CMD=\"foot\"; [ -z \"$TERM_CMD\" ] && command -v kitty >/dev/null 2>&1 && TERM_CMD=\"kitty\"; [ -z \"$TERM_CMD\" ] && command -v alacritty >/dev/null 2>&1 && TERM_CMD=\"alacritty\"; [ -z \"$TERM_CMD\" ] && TERM_CMD=\"xdg-terminal-exec\"; exec $TERM_CMD -e btop"]);
    }

    // ── Функции системного управления ──
    function toggleNightLight() {
        nightLight = !nightLight;
        if (nightLight) {
            Quickshell.execDetached(["sh", "-c", "pkill -x hyprsunset 2>/dev/null; hyprsunset -t " + nightTemp + " >/dev/null 2>&1 &"]);
        } else {
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
        }
    }

    function applyNightTemp(v) {
        nightTemp = Math.round(2600 + v * 3900);
        if (nightLight) {
            Quickshell.execDetached(["sh", "-c", "pkill -x hyprsunset 2>/dev/null; hyprsunset -t " + nightTemp + " >/dev/null 2>&1 &"]);
        }
    }

    function toggleKeepAwake() {
        keepAwake = !keepAwake;
        if (keepAwake) {
            Quickshell.execDetached(["sh", "-c", "systemd-inhibit --what=idle --who='DynamicIsland' --why='KeepAwake' sleep infinity >/dev/null 2>&1 & echo $! > /tmp/di-keepawake.pid"]);
        } else {
            Quickshell.execDetached(["sh", "-c", "[ -f /tmp/di-keepawake.pid ] && kill $(cat /tmp/di-keepawake.pid) 2>/dev/null; rm -f /tmp/di-keepawake.pid"]);
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

    function toggleMic() {
        if (defaultSource && defaultSource.audio) {
            defaultSource.audio.muted = !defaultSource.audio.muted;
        } else {
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
        }
    }

    function takeScreenshotRegion() {
        if (host) host.collapse();
        Quickshell.execDetached(["sh", "-c", "sleep 0.25 && REG=$(slurp) && [ -n \"$REG\" ] && grim -g \"$REG\" - | wl-copy && notify-send -a 'Остров' 'Скриншот' 'Выделенная область скопирована в буфер'"]);
    }

    function takeScreenshotFull() {
        if (host) host.collapse();
        Quickshell.execDetached(["sh", "-c", "sleep 0.25 && grim - | wl-copy && notify-send -a 'Остров' 'Скриншот экрана' 'Полный снимок дисплея скопирован в буфер'"]);
    }

    function lockScreen() {
        if (host) host.collapse();
        Quickshell.execDetached(["sh", "-c", "/home/illidan/.local/share/quickshell/ukishima/scripts/lock.sh 2>/dev/null || hyprctl dispatch dpms off"]);
    }

    function reloadHyprland() {
        Quickshell.execDetached(["sh", "-c", "hyprctl reload && notify-send -a 'Остров' 'Hyprland' 'Конфигурация перезагружена'"]);
    }

    Timer {
        id: brightDebounce
        interval: 300
        onTriggered: {
            const val = Math.round(root.brightness * 100);
            Quickshell.execDetached(["sh", "-c", "command -v brightnessctl >/dev/null 2>&1 && brightnessctl set " + val + "% >/dev/null 2>&1; command -v ddcutil >/dev/null 2>&1 && ddcutil setvcp 10 " + val + " --noverify >/dev/null 2>&1 &"]);
        }
    }

    // ── Основная разметка ──
    Column {
        id: mainCol
        width: parent.width
        spacing: Theme.px(10)

        // 1. Шапка: Профиль пользователя + Аптайм + Системные действия
        Rectangle {
            width: parent.width
            height: Theme.px(54)
            radius: Theme.px(16)
            color: Theme.card

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(10)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(34); height: width
                    radius: width / 2
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
                    spacing: Theme.px(1)

                    Text {
                        text: root.userName + " @ " + root.hostName
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(13)
                        font.weight: Font.Bold
                    }

                    Text {
                        text: "Время работы: " + (SysInfo.uptime !== "" ? SysInfo.uptime : "активен")
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(10)
                        font.features: { "tnum": 1 }
                    }
                }
            }

            // Быстрые кнопки в шапке (Reload, Lock)
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(6)

                // Перезагрузка Hyprland [R]
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(30); height: width; radius: width / 2
                    color: relMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                    scale: relMa.pressed ? 0.90 : 1.0
                    Behavior on scale { Spring { epsilon: 0.002 } }

                    Icon {
                        anchors.centerIn: parent
                        name: "restart_alt"
                        size: Theme.px(16)
                        color: Theme.text
                    }

                    MouseArea {
                        id: relMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.reloadHyprland()
                    }
                }

                // Блокировка экрана [L]
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(30); height: width; radius: width / 2
                    color: lockMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                    scale: lockMa.pressed ? 0.90 : 1.0
                    Behavior on scale { Spring { epsilon: 0.002 } }

                    Icon {
                        anchors.centerIn: parent
                        name: "lock"
                        size: Theme.px(15)
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

        // 2. Главная матрица связи и оборудования ПК (2×2 крупные карточки + выпадающий список аудио)
        Column {
            id: hwCol
            width: parent.width
            spacing: Theme.px(8)
            readonly property real tileW: (width - Theme.px(8)) / 2

            // Ряд 1: Ethernet (LAN) и Аудиовыход
            Item {
                width: parent.width
                height: Theme.px(64)

                // Карточка 1: Проводной Ethernet (LAN)
                Rectangle {
                    id: lanTile
                    anchors.left: parent.left
                    width: parent.parent.tileW
                    height: parent.height
                    radius: Theme.px(16)
                    color: root.ipCopied ? Qt.rgba(Theme.ok.r, Theme.ok.g, Theme.ok.b, 0.22) : (lanMa.containsMouse ? Theme.cardHover : Theme.card)
                    border.width: root.ipCopied ? 1 : 0
                    border.color: Theme.ok
                    scale: lanMa.pressed ? 0.94 : 1.0
                    Behavior on scale { Spring {} }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.px(10)
                        spacing: Theme.px(10)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(34); height: width; radius: width / 2
                            color: root.ipCopied ? Theme.ok : Qt.rgba(1, 1, 1, 0.1)

                            Icon {
                                anchors.centerIn: parent
                                name: root.ipCopied ? "check" : "lan"
                                size: Theme.px(18)
                                color: root.ipCopied ? "#000000" : Theme.controlFill
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.px(44)
                            spacing: Theme.px(1)

                            Row {
                                spacing: Theme.px(4)
                                Text {
                                    text: "Ethernet"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(12)
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: "(" + root.lanInterface + ")"
                                    color: Theme.text3
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(10)
                                }
                            }

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: root.ipCopied ? "IP скопирован в буфер!" : (root.lanIp !== "" ? root.lanIp : "Подключено")
                                color: root.ipCopied ? Theme.ok : Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: root.ipCopied ? Font.Bold : Font.Normal
                                font.features: { "tnum": 1 }
                            }

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: "↓ " + SysInfo.netDown + " · ↑ " + SysInfo.netUp
                                color: Theme.text3
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(9)
                                font.features: { "tnum": 1 }
                            }
                        }
                    }

                    MouseArea {
                        id: lanMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                Quickshell.execDetached(["sh", "-c", "command -v nm-connection-editor >/dev/null 2>&1 && nm-connection-editor || command -v kitty >/dev/null 2>&1 && kitty -e nmtui || nmtui"]);
                            } else {
                                root.copyLanIp();
                            }
                        }
                    }
                }

                // Карточка 2: Аудиовыход (PipeWire Sink с раскрывающимся меню)
                Rectangle {
                    id: audioTile
                    anchors.right: parent.right
                    width: parent.parent.tileW
                    height: parent.height
                    radius: Theme.px(16)
                    color: root.audioMenuOpen ? Qt.rgba(1, 1, 1, 0.14) : (audioMa.containsMouse ? Theme.cardHover : Theme.card)
                    border.width: root.audioMenuOpen ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.35)
                    scale: audioMa.pressed ? 0.95 : 1.0
                    Behavior on scale { Spring {} }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.px(10)
                        spacing: Theme.px(10)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(34); height: width; radius: width / 2
                            color: Audio.muted
                                ? Qt.rgba(Theme.alert.r, Theme.alert.g, Theme.alert.b, 0.2)
                                : (root.audioMenuOpen ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.1))

                            Icon {
                                anchors.centerIn: parent
                                name: Audio.muted ? "volume_off" : root.sinkIcon(Audio.sink)
                                size: Theme.px(18)
                                color: Audio.muted ? Theme.alert : (root.audioMenuOpen ? "#000000" : Theme.text)
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.px(70)
                            spacing: Theme.px(1)

                            Text {
                                text: "Аудиовыход"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.Bold
                            }

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: root.cleanSinkName(Audio.sink)
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                            }

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: Audio.muted ? "Звук выключен" : (Math.round(Audio.volume * 100) + "% · Устройства")
                                color: Audio.muted ? Theme.alert : Theme.text3
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(9)
                                font.features: { "tnum": 1 }
                            }
                        }

                        // Стрелка раскрытия списка в круглой капсуле
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(22); height: width; radius: width / 2
                            color: root.audioMenuOpen ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.06)

                            Icon {
                                anchors.centerIn: parent
                                name: "expand_more"
                                size: Theme.px(15)
                                color: root.audioMenuOpen ? Theme.controlFill : Theme.text2
                                rotation: root.audioMenuOpen ? 180 : 0
                                Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            }
                        }
                    }

                    MouseArea {
                        id: audioMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.audioMenuOpen = !root.audioMenuOpen
                    }
                }
            }

            // Выпадающий блок выбора аудиоустройств (раскрывается плавно без перекрытия элементов)
            Rectangle {
                id: audioDrawer
                width: parent.width
                visible: height > 0
                height: root.audioMenuOpen ? (dropCol.implicitHeight + Theme.px(20)) : 0
                radius: Theme.px(16)
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: root.audioMenuOpen ? 1 : 0
                border.color: Theme.divider
                clip: true
                opacity: root.audioMenuOpen ? 1.0 : 0.0
                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 160 } }

                Column {
                    id: dropCol
                    width: parent.width - Theme.px(20)
                    x: Theme.px(10)
                    y: Theme.px(10)
                    spacing: Theme.px(5)

                    // Шапка списка устройств + быстрый переход в Pavucontrol
                    Item {
                        width: parent.width
                        height: Theme.px(20)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.px(4)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(6)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "speaker_group"
                                size: Theme.px(13)
                                color: Theme.text2
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "УСТРОЙСТВО ВЫВОДА ЗВУКА"
                                color: Theme.text3
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(9)
                                font.weight: Font.Bold
                                font.letterSpacing: 0.5
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: pavuHdrRow.implicitWidth + Theme.px(12)
                            height: Theme.px(20)
                            radius: Theme.px(6)
                            color: pavuHdrMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)

                            Row {
                                id: pavuHdrRow
                                anchors.centerIn: parent
                                spacing: Theme.px(4)
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "tune"
                                    size: Theme.px(11)
                                    color: Theme.text2
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Микшер"
                                    color: Theme.text2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(9)
                                    font.weight: Font.DemiBold
                                }
                            }
                            MouseArea {
                                id: pavuHdrMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["pavucontrol"]);
                                    root.audioMenuOpen = false;
                                }
                            }
                        }
                    }

                    Repeater {
                        model: root.sinks
                        Rectangle {
                            id: sinkItem
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: Theme.px(36)
                            radius: Theme.px(10)
                            readonly property bool isCurrent: root.isDefaultSink(modelData)
                            color: isCurrent
                                ? Theme.controlFill
                                : (sinkItemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04))
                            scale: sinkItemMa.pressed ? 0.98 : 1.0
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on scale { Spring { epsilon: 0.002 } }

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.px(10)
                                anchors.rightMargin: Theme.px(10)

                                Icon {
                                    id: sIcon
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: root.sinkIcon(sinkItem.modelData)
                                    size: Theme.px(16)
                                    color: sinkItem.isCurrent ? "#000000" : Theme.text2
                                }

                                Text {
                                    anchors.left: sIcon.right
                                    anchors.leftMargin: Theme.px(8)
                                    anchors.right: sBadge.left
                                    anchors.rightMargin: Theme.px(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    text: root.cleanSinkName(sinkItem.modelData)
                                    color: sinkItem.isCurrent ? "#000000" : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(11)
                                    font.weight: sinkItem.isCurrent ? Font.Bold : Font.Medium
                                }

                                Row {
                                    id: sBadge
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.px(4)

                                    Text {
                                        visible: sinkItem.isCurrent
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Активно"
                                        color: "#000000"
                                        opacity: 0.65
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.px(9)
                                        font.weight: Font.Bold
                                    }

                                    Icon {
                                        visible: sinkItem.isCurrent
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "check_circle"
                                        size: Theme.px(15)
                                        color: "#000000"
                                    }
                                }
                            }

                            MouseArea {
                                id: sinkItemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Pipewire.preferredDefaultAudioSink = sinkItem.modelData;
                                    root.audioMenuOpen = false;
                                }
                            }
                        }
                    }
                }
            }

            // Ряд 2: Ночной свет и Не беспокоить
            Row {
                width: parent.width
                spacing: Theme.px(8)

                // Карточка 3: Ночной свет [N]
                Rectangle {
                    width: parent.parent.tileW
                    height: Theme.px(60)
                    radius: Theme.px(16)
                    color: root.nightLight ? Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.22) : Theme.card
                    border.width: 1
                    border.color: root.nightLight ? Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.55) : Theme.divider
                    scale: nlMa.pressed ? 0.94 : 1.0
                    Behavior on scale { Spring {} }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.px(10)
                        spacing: Theme.px(10)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(34); height: width; radius: width / 2
                            color: root.nightLight ? Theme.warn : Qt.rgba(1, 1, 1, 0.1)

                            Icon {
                                anchors.centerIn: parent
                                name: "nightlight"
                                size: Theme.px(17)
                                color: root.nightLight ? "#000000" : Theme.text2
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.px(44)
                            spacing: Theme.px(1)

                            Text {
                                text: "Ночной свет"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.Bold
                            }

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: root.nightLight ? (root.nightTemp + "K · Включен") : "[N] Выключен"
                                color: root.nightLight ? Theme.warn : Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                            }
                        }
                    }

                    MouseArea {
                        id: nlMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleNightLight()
                    }
                }

                // Карточка 4: Не беспокоить [D]
                Rectangle {
                    width: parent.parent.tileW
                    height: Theme.px(60)
                    radius: Theme.px(16)
                    color: Notifs.dnd ? Qt.rgba(Theme.purple.r, Theme.purple.g, Theme.purple.b, 0.22) : Theme.card
                    border.width: 1
                    border.color: Notifs.dnd ? Qt.rgba(Theme.purple.r, Theme.purple.g, Theme.purple.b, 0.55) : Theme.divider
                    scale: dndMa.pressed ? 0.94 : 1.0
                    Behavior on scale { Spring {} }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.px(10)
                        spacing: Theme.px(10)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(34); height: width; radius: width / 2
                            color: Notifs.dnd ? Theme.purple : Qt.rgba(1, 1, 1, 0.1)

                            Icon {
                                anchors.centerIn: parent
                                name: "do_not_disturb_on"
                                size: Theme.px(17)
                                color: Notifs.dnd ? "#FFFFFF" : Theme.text2
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.px(44)
                            spacing: Theme.px(1)

                            Text {
                                text: "Не беспокоить"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.Bold
                            }

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: Notifs.dnd ? "Уведомления заглушены" : "[D] Обычные уведомления"
                                color: Notifs.dnd ? Theme.purple : Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                            }
                        }
                    }

                    MouseArea {
                        id: dndMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                }
            }
        }

        // 3. Ползунки управления: Яркость монитора + Теплота ночного света
        Column {
            width: parent.width
            spacing: Theme.px(8)

            // Слайдер яркости монитора
            Rectangle {
                width: parent.width
                height: Theme.px(46)
                radius: Theme.px(14)
                color: Theme.card

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.px(12)
                    spacing: Theme.px(10)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "light_mode"
                        size: Theme.px(18)
                        color: Theme.controlFill
                    }

                    Bar {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.px(76)
                        height: Theme.px(6)
                        value: root.brightness
                        tint: Theme.controlFill
                        interactive: true
                        onMoved: v => { root.brightness = v; brightDebounce.restart(); }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.brightness * 100) + "%"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }
                }
            }

            // Слайдер теплоты ночного света
            Rectangle {
                visible: root.nightLight
                width: parent.width
                height: Theme.px(46)
                radius: Theme.px(14)
                color: Theme.card

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.px(12)
                    spacing: Theme.px(10)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "thermostat"
                        size: Theme.px(17)
                        color: Theme.warn
                    }

                    Bar {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.px(76)
                        height: Theme.px(6)
                        value: (root.nightTemp - 2600) / 3900
                        tint: Theme.warn
                        interactive: true
                        onMoved: v => root.applyNightTemp(v)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.nightTemp + "K"
                        color: Theme.warn
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }

        // 4. НАСТРОЙКИ ЧЁЛКИ И ДАШБОРДА (Dynamic Notch & Dashboard Configuration)
        Rectangle {
            width: parent.width
            implicitHeight: prefsCol.implicitHeight + Theme.px(24)
            radius: Theme.px(16)
            color: Theme.card

            Column {
                id: prefsCol
                width: parent.width - 2 * Theme.px(12)
                x: Theme.px(12)
                y: Theme.px(12)
                spacing: Theme.px(10)

                // Заголовок секции
                Row {
                    spacing: Theme.px(6)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "tune"
                        size: Theme.px(16)
                        color: Theme.controlFill
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Настройки чёлки и дашборда"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.Bold
                    }
                }

                // Переключатель виджета в свернутой чёлке (Segmented selector)
                Column {
                    width: parent.width
                    spacing: Theme.px(5)

                    Text {
                        text: "Индикатор в свернутой чёлке"
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.px(4)
                        readonly property real segW: (width - 3 * spacing) / 4

                        // Вариант 1: Погода
                        Rectangle {
                            width: parent.segW; height: Theme.px(30); radius: Theme.px(8)
                            color: IslandPrefs.compactWidget === "weather" ? Theme.controlFill : (wthMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.05))
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(4)
                                Icon { name: "cloud"; size: Theme.px(13); color: IslandPrefs.compactWidget === "weather" ? "#000000" : Theme.text }
                                Text { text: "Погода"; color: IslandPrefs.compactWidget === "weather" ? "#000000" : Theme.text; font.pixelSize: Theme.px(10); font.weight: Font.DemiBold }
                            }
                            MouseArea {
                                id: wthMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandPrefs.setCompactWidget("weather")
                            }
                        }

                        // Вариант 2: CPU и температура
                        Rectangle {
                            width: parent.segW; height: Theme.px(30); radius: Theme.px(8)
                            color: IslandPrefs.compactWidget === "cpu" ? Theme.controlFill : (cpuMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.05))
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(4)
                                Icon { name: "memory"; size: Theme.px(13); color: IslandPrefs.compactWidget === "cpu" ? "#000000" : Theme.text }
                                Text { text: "ЦП / Темп"; color: IslandPrefs.compactWidget === "cpu" ? "#000000" : Theme.text; font.pixelSize: Theme.px(10); font.weight: Font.DemiBold }
                            }
                            MouseArea {
                                id: cpuMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandPrefs.setCompactWidget("cpu")
                            }
                        }

                        // Вариант 3: Сеть (LAN)
                        Rectangle {
                            width: parent.segW; height: Theme.px(30); radius: Theme.px(8)
                            color: IslandPrefs.compactWidget === "net" ? Theme.controlFill : (netMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.05))
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(4)
                                Icon { name: "swap_vert"; size: Theme.px(13); color: IslandPrefs.compactWidget === "net" ? "#000000" : Theme.text }
                                Text { text: "Сеть LAN"; color: IslandPrefs.compactWidget === "net" ? "#000000" : Theme.text; font.pixelSize: Theme.px(10); font.weight: Font.DemiBold }
                            }
                            MouseArea {
                                id: netMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandPrefs.setCompactWidget("net")
                            }
                        }

                        // Вариант 4: Скрыть
                        Rectangle {
                            width: parent.segW; height: Theme.px(30); radius: Theme.px(8)
                            color: IslandPrefs.compactWidget === "none" ? Theme.controlFill : (noneMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.05))
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(4)
                                Icon { name: "visibility_off"; size: Theme.px(13); color: IslandPrefs.compactWidget === "none" ? "#000000" : Theme.text }
                                Text { text: "Скрыть"; color: IslandPrefs.compactWidget === "none" ? "#000000" : Theme.text; font.pixelSize: Theme.px(10); font.weight: Font.DemiBold }
                            }
                            MouseArea {
                                id: noneMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandPrefs.setCompactWidget("none")
                            }
                        }
                    }
                }

                // Разделитель
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.divider
                }

                // Настройка: Секунды в часах
                Item {
                    width: parent.width
                    height: Theme.px(32)

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(8)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "schedule"
                            size: Theme.px(16)
                            color: Theme.text
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(1)
                            Text {
                                text: "Секунды в часах"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: IslandPrefs.showSeconds ? "Формат: ЧЧ:ММ:СС" : "Формат: ЧЧ:ММ"
                                color: Theme.text3
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(9)
                            }
                        }
                    }

                    // Переключатель (Toggle Switch)
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(38); height: Theme.px(20); radius: height / 2
                        color: IslandPrefs.showSeconds ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.12)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            y: Theme.px(2)
                            x: IslandPrefs.showSeconds ? parent.width - width - Theme.px(2) : Theme.px(2)
                            width: Theme.px(16); height: width; radius: width / 2
                            color: IslandPrefs.showSeconds ? "#000000" : Theme.text2
                            Behavior on x { Spring { spring: 260; damping: 20 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: IslandPrefs.toggleSeconds()
                        }
                    }
                }

                // Настройка: Всплывающий OSD (Громкость и Раскладка)
                Item {
                    width: parent.width
                    height: Theme.px(32)

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(8)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "smart_display"
                            size: Theme.px(16)
                            color: Theme.text
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(1)
                            Text {
                                text: "Всплывающие плашки (OSD)"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "Индикаторы громкости и языка в чёлке"
                                color: Theme.text3
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(9)
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(5)

                        // OSD громкости
                        Rectangle {
                            width: Theme.px(64); height: Theme.px(24); radius: Theme.px(6)
                            color: IslandPrefs.showVolumeOsd ? Qt.rgba(Theme.controlFill.r, Theme.controlFill.g, Theme.controlFill.b, 0.22) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: IslandPrefs.showVolumeOsd ? Theme.controlFill : Theme.divider
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(3)
                                Icon { name: "volume_up"; size: Theme.px(12); color: IslandPrefs.showVolumeOsd ? Theme.controlFill : Theme.text3 }
                                Text { text: "Звук"; color: IslandPrefs.showVolumeOsd ? Theme.controlFill : Theme.text3; font.pixelSize: Theme.px(9); font.weight: Font.DemiBold }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandPrefs.toggleVolumeOsd()
                            }
                        }

                        // OSD раскладки
                        Rectangle {
                            width: Theme.px(64); height: Theme.px(24); radius: Theme.px(6)
                            color: IslandPrefs.showLayoutOsd ? Qt.rgba(Theme.controlFill.r, Theme.controlFill.g, Theme.controlFill.b, 0.22) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: IslandPrefs.showLayoutOsd ? Theme.controlFill : Theme.divider
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.px(3)
                                Icon { name: "language"; size: Theme.px(12); color: IslandPrefs.showLayoutOsd ? Theme.controlFill : Theme.text3 }
                                Text { text: "Язык"; color: IslandPrefs.showLayoutOsd ? Theme.controlFill : Theme.text3; font.pixelSize: Theme.px(9); font.weight: Font.DemiBold }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandPrefs.toggleLayoutOsd()
                            }
                        }
                    }
                }

                // Настройка: Автосворачивание дашборда
                Item {
                    width: parent.width
                    height: Theme.px(32)

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(8)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "expand"
                            size: Theme.px(16)
                            color: Theme.text
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(1)
                            Text {
                                text: "Автосворачивание"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "Сворачивать при уводе курсора мыши"
                                color: Theme.text3
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(9)
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(38); height: Theme.px(20); radius: height / 2
                        color: IslandPrefs.autoCollapse ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.12)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            y: Theme.px(2)
                            x: IslandPrefs.autoCollapse ? parent.width - width - Theme.px(2) : Theme.px(2)
                            width: Theme.px(16); height: width; radius: width / 2
                            color: IslandPrefs.autoCollapse ? "#000000" : Theme.text2
                            Behavior on x { Spring { spring: 260; damping: 20 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: IslandPrefs.toggleAutoCollapse()
                        }
                    }
                }
            }
        }

        // 5. Быстрые переключатели функций (4 горизонтальные чипсы-кнопки)
        Row {
            width: parent.width
            spacing: Theme.px(6)
            readonly property real chipW: (width - 3 * spacing) / 4

            // Игровой режим [G]
            Rectangle {
                id: gmChip
                width: parent.chipW
                height: Theme.px(42)
                radius: Theme.px(12)
                color: root.gameMode ? Theme.controlFill : (gmMa.containsMouse ? Theme.cardHover : Theme.card)
                scale: gmMa.pressed ? 0.92 : 1.0
                Behavior on scale { Spring {} }
                Behavior on color { ColorAnimation { duration: 140 } }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(5)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "sports_esports"
                        size: Theme.px(16)
                        color: root.gameMode ? "#000000" : Theme.text
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Игровой [G]"
                        color: root.gameMode ? "#000000" : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(10)
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: gmMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleGameMode()
                }
            }

            // Не усыплять [A] (предотвращает блокировку экрана и спящий режим)
            Rectangle {
                id: awakeChip
                width: parent.chipW
                height: Theme.px(42)
                radius: Theme.px(12)
                color: root.keepAwake ? Theme.controlFill : (awakeMa.containsMouse ? Theme.cardHover : Theme.card)
                scale: awakeMa.pressed ? 0.92 : 1.0
                Behavior on scale { Spring {} }
                Behavior on color { ColorAnimation { duration: 140 } }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(5)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "coffee"
                        size: Theme.px(16)
                        color: root.keepAwake ? "#000000" : Theme.text
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Без сна [A]"
                        color: root.keepAwake ? "#000000" : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(10)
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: awakeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleKeepAwake()
                }
            }

            // Микрофон [M]
            Rectangle {
                id: micChip
                width: parent.chipW
                height: Theme.px(42)
                radius: Theme.px(12)
                color: root.micMuted ? Qt.rgba(Theme.alert.r, Theme.alert.g, Theme.alert.b, 0.22) : (micMa.containsMouse ? Theme.cardHover : Theme.card)
                border.width: root.micMuted ? 1 : 0
                border.color: Theme.alert
                scale: micMa.pressed ? 0.92 : 1.0
                Behavior on scale { Spring {} }
                Behavior on color { ColorAnimation { duration: 140 } }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(5)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.micMuted ? "mic_off" : "mic"
                        size: Theme.px(16)
                        color: root.micMuted ? Theme.alert : Theme.text
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.micMuted ? "Заглушен" : "Микро [M]"
                        color: root.micMuted ? Theme.alert : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(10)
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: micMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMic()
                }
            }

            // Запись экрана
            Rectangle {
                id: recChip
                width: parent.chipW
                height: Theme.px(42)
                radius: Theme.px(12)
                color: Recorder.recording ? Qt.rgba(Theme.alert.r, Theme.alert.g, Theme.alert.b, 0.25) : (recMa.containsMouse ? Theme.cardHover : Theme.card)
                border.width: Recorder.recording ? 1 : 0
                border.color: Theme.alert
                scale: recMa.pressed ? 0.92 : 1.0
                Behavior on scale { Spring {} }
                Behavior on color { ColorAnimation { duration: 140 } }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(5)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "videocam"
                        size: Theme.px(16)
                        color: Recorder.recording ? Theme.alert : Theme.text
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Recorder.recording ? Recorder.elapsedText : "Запись"
                        color: Recorder.recording ? Theme.alert : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(10)
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: recMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Recorder.recording) Recorder.stop();
                        else {
                            if (host) host.collapse();
                            Recorder.start("screen");
                        }
                    }
                }
            }
        }

        // 6. Хаб снимков экрана (Снимок выделенной области и Снимок всего экрана)
        Rectangle {
            width: parent.width
            implicitHeight: scCol.implicitHeight + Theme.px(20)
            radius: Theme.px(16)
            color: Theme.card

            Column {
                id: scCol
                width: parent.width - 2 * Theme.px(12)
                x: Theme.px(12)
                y: Theme.px(10)
                spacing: Theme.px(8)

                Row {
                    spacing: Theme.px(6)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "photo_camera"
                        size: Theme.px(16)
                        color: Theme.controlFill
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Снимки экрана"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.Bold
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.px(8)
                    readonly property real scBtnW: (width - spacing) / 2

                    // Кнопка 1: Снимок выделенной области
                    Rectangle {
                        width: parent.scBtnW
                        height: Theme.px(48)
                        radius: Theme.px(12)
                        color: scRegMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.05)
                        scale: scRegMa.pressed ? 0.95 : 1.0
                        Behavior on scale { Spring { epsilon: 0.002 } }

                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.px(10)
                            spacing: Theme.px(8)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "crop"
                                size: Theme.px(18)
                                color: Theme.text
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.px(1)

                                Text {
                                    text: "Снимок области [S]"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(11)
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text: "Выделить прямоугольник"
                                    color: Theme.text3
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(9)
                                }
                            }
                        }

                        MouseArea {
                            id: scRegMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.takeScreenshotRegion()
                        }
                    }

                    // Кнопка 2: Снимок всего экрана
                    Rectangle {
                        width: parent.scBtnW
                        height: Theme.px(48)
                        radius: Theme.px(12)
                        color: scFullMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.05)
                        scale: scFullMa.pressed ? 0.95 : 1.0
                        Behavior on scale { Spring { epsilon: 0.002 } }

                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.px(10)
                            spacing: Theme.px(8)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "fullscreen"
                                size: Theme.px(18)
                                color: Theme.text
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.px(1)

                                Text {
                                    text: "Снимок всего экрана"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(11)
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text: "Сфотографировать дисплей"
                                    color: Theme.text3
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(9)
                                }
                            }
                        }

                        MouseArea {
                            id: scFullMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.takeScreenshotFull()
                        }
                    }
                }
            }
        }

        // 7. Быстрый запуск системных утилит (Pavucontrol, Btop, Терминал по конфигу пользователя)
        Row {
            width: parent.width
            spacing: Theme.px(6)
            readonly property real btnW: (width - 2 * spacing) / 3

            // Pavucontrol
            Rectangle {
                width: parent.btnW
                height: Theme.px(36)
                radius: Theme.px(10)
                color: pavuMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.05)
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(5)
                    Icon { name: "tune"; size: Theme.px(14); color: Theme.text2 }
                    Text { text: "Pavucontrol"; color: Theme.text2; font.family: Theme.fontFamily; font.pixelSize: Theme.px(10); font.weight: Font.Medium }
                }
                MouseArea {
                    id: pavuMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["pavucontrol"])
                }
            }

            // Btop
            Rectangle {
                width: parent.btnW
                height: Theme.px(36)
                radius: Theme.px(10)
                color: btopMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.05)
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(5)
                    Icon { name: "speed"; size: Theme.px(14); color: Theme.text2 }
                    Text { text: "Btop"; color: Theme.text2; font.family: Theme.fontFamily; font.pixelSize: Theme.px(10); font.weight: Font.Medium }
                }
                MouseArea {
                    id: btopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openBtop()
                }
            }

            // Терминал (по бинду пользователя — foot)
            Rectangle {
                width: parent.btnW
                height: Theme.px(36)
                radius: Theme.px(10)
                color: termMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.05)
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(5)
                    Icon { name: "terminal"; size: Theme.px(14); color: Theme.text2 }
                    Text { text: "Терминал"; color: Theme.text2; font.family: Theme.fontFamily; font.pixelSize: Theme.px(10); font.weight: Font.Medium }
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
