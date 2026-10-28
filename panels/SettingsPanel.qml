import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// Панель быстрых настроек (Control Center). Клавиши: N — Ночной свет, D — Не беспокоить, A — Не спать, G — Игровой режим, S — Скриншот, ←/→ — Яркость.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property bool nightLight: false
    property int nightTemp: 4200
    property bool keepAwake: false
    property bool gameMode: false
    property real brightness: 0.8

    implicitHeight: col.implicitHeight

    Keys.onPressed: event => {
        if (event.key === Qt.Key_N) { toggleNightLight(); event.accepted = true; }
        else if (event.key === Qt.Key_D) { Notifs.dnd = !Notifs.dnd; event.accepted = true; }
        else if (event.key === Qt.Key_A) { toggleKeepAwake(); event.accepted = true; }
        else if (event.key === Qt.Key_G) { toggleGameMode(); event.accepted = true; }
        else if (event.key === Qt.Key_S) { takeScreenshot(); event.accepted = true; }
        else if (event.key === Qt.Key_Left) {
            brightness = Math.max(0.05, brightness - 0.05);
            ddcDebounce.restart();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            brightness = Math.min(1.0, brightness + 0.05);
            ddcDebounce.restart();
            event.accepted = true;
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

    function applyNightTemp(v) {
        nightTemp = Math.round(2800 + v * 3200);
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

    function takeScreenshot() {
        if (host) host.collapse();
        Quickshell.execDetached(["sh", "-c", "sleep 0.25 && REG=$(slurp) && [ -n \"$REG\" ] && grim -g \"$REG\" - | wl-copy && notify-send 'Скриншот' 'Скопировано в буфер обмена'"]);
    }

    Timer {
        id: ddcDebounce
        interval: 350
        onTriggered: {
            const val = Math.round(root.brightness * 100);
            Quickshell.execDetached(["sh", "-c", "command -v brightnessctl >/dev/null 2>&1 && brightnessctl set " + val + "% >/dev/null 2>&1; command -v ddcutil >/dev/null 2>&1 && ddcutil setvcp 10 " + val + " --noverify >/dev/null 2>&1 &"]);
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        // Плитки в стиле iOS Control Center (4 штуки в ряд)
        Row {
            width: parent.width
            spacing: Theme.px(10)
            readonly property real tileW: (width - 3 * spacing) / 4

            Repeater {
                model: [
                    { key: "night", icon: "nightlight", title: "Ночной свет", sub: root.nightLight ? (root.nightTemp + "K") : "[N] Выкл", on: root.nightLight, color: Theme.orange },
                    { key: "dnd", icon: "do_not_disturb_on", title: "Не беспокоить", sub: Notifs.dnd ? "Включено" : "[D] Выкл", on: Notifs.dnd, color: Theme.purple },
                    { key: "awake", icon: "coffee", title: "Не спать", sub: root.keepAwake ? "Активно" : "[A] Выкл", on: root.keepAwake, color: Theme.green },
                    { key: "game", icon: "sports_esports", title: "Игровой режим", sub: root.gameMode ? "Ускорение" : "[G] Выкл", on: root.gameMode, color: Theme.blue }
                ]

                Rectangle {
                    id: cTile
                    required property var modelData
                    width: parent.tileW
                    height: Theme.px(72)
                    radius: Theme.px(18)
                    color: modelData.on ? modelData.color : (tMa.containsMouse ? Theme.cardHover : Theme.card)
                    scale: tMa.pressed ? 0.94 : 1.0
                    Behavior on scale { Spring {} }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.px(12)
                        spacing: Theme.px(10)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(34); height: width; radius: width / 2
                            color: cTile.modelData.on ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(1, 1, 1, 0.1)
                            Icon {
                                anchors.centerIn: parent
                                name: cTile.modelData.icon
                                size: Theme.px(17)
                                color: "white"
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.px(44)
                            spacing: Theme.px(2)
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: cTile.modelData.title
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.Bold
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: cTile.modelData.sub
                                color: cTile.modelData.on ? Qt.rgba(1, 1, 1, 0.85) : Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                            }
                        }
                    }

                    MouseArea {
                        id: tMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const k = cTile.modelData.key;
                            if (k === "night") root.toggleNightLight();
                            else if (k === "dnd") Notifs.dnd = !Notifs.dnd;
                            else if (k === "awake") root.toggleKeepAwake();
                            else if (k === "game") root.toggleGameMode();
                        }
                    }
                }
            }
        }

        // Нижний ряд: Слайдер яркости + Температура ночного света + Быстрый скриншот
        Row {
            width: parent.width
            spacing: Theme.px(10)

            // Яркость монитора
            Rectangle {
                width: (parent.width - 2 * parent.spacing) * 0.42
                height: Theme.px(56)
                radius: Theme.px(18)
                color: Theme.card

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.px(14)
                    spacing: Theme.px(12)

                    Icon { name: "light_mode"; size: Theme.px(20); color: Theme.yellow; anchors.verticalCenter: parent.verticalCenter }
                    Bar {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.px(80)
                        height: Theme.px(8)
                        value: root.brightness
                        tint: Theme.yellow
                        interactive: true
                        onMoved: v => { root.brightness = v; ddcDebounce.restart(); }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.brightness * 100) + "%"
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.Bold
                    }
                }
            }

            // Теплота ночного света
            Rectangle {
                width: (parent.width - 2 * parent.spacing) * 0.36
                height: Theme.px(56)
                radius: Theme.px(18)
                color: Theme.card

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.px(14)
                    spacing: Theme.px(10)

                    Icon { name: "thermostat"; size: Theme.px(19); color: Theme.orange; anchors.verticalCenter: parent.verticalCenter }
                    Bar {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.px(84)
                        height: Theme.px(8)
                        value: (root.nightTemp - 2800) / 3200
                        tint: Theme.orange
                        interactive: true
                        onMoved: v => root.applyNightTemp(v)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.nightTemp + "K"
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                        font.weight: Font.Bold
                    }
                }
            }

            // Скриншот области
            Rectangle {
                width: (parent.width - 2 * parent.spacing) * 0.22
                height: Theme.px(56)
                radius: Theme.px(18)
                color: scMa.containsMouse ? Theme.cardHover : Theme.card

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(8)
                    Icon { name: "screenshot_region"; size: Theme.px(19); color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Скриншот"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: scMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.takeScreenshot()
                }
            }
        }
    }
}
