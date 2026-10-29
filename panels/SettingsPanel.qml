import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// Панель быстрых настроек (Control Center).
// Клавиши: N — Ночной свет, D — Не беспокоить, A — Не спать, G — Игровой режим, S — Скриншот, ←/→ — Яркость.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property bool nightLight: false
    property int nightTemp: 4200
    property bool keepAwake: false
    property bool gameMode: false
    property real brightness: 0.8

    implicitWidth: Theme.px(420)
    implicitHeight: col.implicitHeight

    Keys.onPressed: event => {
        const t = (event.text || "").toLowerCase();
        if (event.key === Qt.Key_N || t === "n" || t === "т") { toggleNightLight(); event.accepted = true; }
        else if (event.key === Qt.Key_D || t === "d" || t === "в") { Notifs.dnd = !Notifs.dnd; event.accepted = true; }
        else if (event.key === Qt.Key_A || t === "a" || t === "ф") { toggleKeepAwake(); event.accepted = true; }
        else if (event.key === Qt.Key_G || t === "g" || t === "п") { toggleGameMode(); event.accepted = true; }
        else if (event.key === Qt.Key_S || t === "s" || t === "ы") { takeScreenshot(); event.accepted = true; }
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
        spacing: Theme.px(8)

        // Сетка 2×2 быстрых настроек
        Column {
            width: parent.width
            spacing: Theme.px(8)

            readonly property var row1Tiles: [
                { key: "night", icon: "nightlight", title: "Ночной свет", sub: root.nightLight ? (root.nightTemp + "K") : "[N] Выкл", on: root.nightLight, color: Theme.warn },
                { key: "dnd", icon: "do_not_disturb_on", title: "Не беспокоить", sub: Notifs.dnd ? "Включено" : "[D] Выкл", on: Notifs.dnd, color: Theme.purple }
            ]

            readonly property var row2Tiles: [
                { key: "awake", icon: "coffee", title: "Не спать", sub: root.keepAwake ? "Активно" : "[A] Выкл", on: root.keepAwake, color: Theme.green },
                { key: "game", icon: "sports_esports", title: "Игровой режим", sub: root.gameMode ? "Ускорение" : "[G] Выкл", on: root.gameMode, color: Theme.blue }
            ]

            function handleKey(k) {
                if (k === "night") root.toggleNightLight();
                else if (k === "dnd") Notifs.dnd = !Notifs.dnd;
                else if (k === "awake") root.toggleKeepAwake();
                else if (k === "game") root.toggleGameMode();
            }

            Row {
                width: parent.width
                spacing: Theme.px(8)
                readonly property real tileW: (width - spacing) / 2

                Repeater {
                    model: parent.parent.row1Tiles
                    Rectangle {
                        id: cTile1
                        required property var modelData
                        width: parent.tileW
                        height: Theme.px(60)
                        radius: Theme.px(16)
                        color: modelData.on ? modelData.color : (tMa1.containsMouse ? Theme.cardHover : Theme.card)
                        scale: tMa1.pressed ? 0.94 : 1.0
                        Behavior on scale { Spring {} }
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.px(10)
                            spacing: Theme.px(9)

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(32); height: width; radius: width / 2
                                color: cTile1.modelData.on ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(1, 1, 1, 0.1)
                                Icon {
                                    anchors.centerIn: parent
                                    name: cTile1.modelData.icon
                                    size: Theme.px(16)
                                    color: "white"
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Theme.px(42)
                                spacing: Theme.px(1)
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: cTile1.modelData.title
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(12)
                                    font.weight: Font.Bold
                                }
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: cTile1.modelData.sub
                                    color: cTile1.modelData.on ? Qt.rgba(1, 1, 1, 0.85) : Theme.text2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(10)
                                }
                            }
                        }

                        MouseArea {
                            id: tMa1
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.parent.parent.handleKey(cTile1.modelData.key)
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.px(8)
                readonly property real tileW: (width - spacing) / 2

                Repeater {
                    model: parent.parent.row2Tiles
                    Rectangle {
                        id: cTile2
                        required property var modelData
                        width: parent.tileW
                        height: Theme.px(60)
                        radius: Theme.px(16)
                        color: modelData.on ? modelData.color : (tMa2.containsMouse ? Theme.cardHover : Theme.card)
                        scale: tMa2.pressed ? 0.94 : 1.0
                        Behavior on scale { Spring {} }
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.px(10)
                            spacing: Theme.px(9)

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(32); height: width; radius: width / 2
                                color: cTile2.modelData.on ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(1, 1, 1, 0.1)
                                Icon {
                                    anchors.centerIn: parent
                                    name: cTile2.modelData.icon
                                    size: Theme.px(16)
                                    color: "white"
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Theme.px(42)
                                spacing: Theme.px(1)
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: cTile2.modelData.title
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(12)
                                    font.weight: Font.Bold
                                }
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: cTile2.modelData.sub
                                    color: cTile2.modelData.on ? Qt.rgba(1, 1, 1, 0.85) : Theme.text2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(10)
                                }
                            }
                        }

                        MouseArea {
                            id: tMa2
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.parent.parent.handleKey(cTile2.modelData.key)
                        }
                    }
                }
            }
        }

        // Слайдер яркости монитора (полная ширина карточки)
        Rectangle {
            width: parent.width
            height: Theme.px(48)
            radius: Theme.px(16)
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
                    height: Theme.px(7)
                    value: root.brightness
                    tint: Theme.controlFill
                    interactive: true
                    onMoved: v => { root.brightness = v; ddcDebounce.restart(); }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.brightness * 100) + "%"
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                }
            }
        }

        // Нижний ряд: Температура ночного света + Скриншот
        Row {
            width: parent.width
            spacing: Theme.px(8)

            // Теплота ночного света
            Rectangle {
                width: parent.width * 0.62 - Theme.px(4)
                height: Theme.px(48)
                radius: Theme.px(16)
                color: Theme.card

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.px(12)
                    spacing: Theme.px(8)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "thermostat"
                        size: Theme.px(17)
                        color: root.nightLight ? Theme.warn : Theme.text2
                    }

                    Bar {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.px(76)
                        height: Theme.px(7)
                        value: (root.nightTemp - 2800) / 3200
                        tint: root.nightLight ? Theme.warn : Theme.controlFill
                        interactive: true
                        onMoved: v => root.applyNightTemp(v)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.nightTemp + "K"
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(10)
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }
                }
            }

            // Быстрый скриншот области
            Rectangle {
                width: parent.width * 0.38 - Theme.px(4)
                height: Theme.px(48)
                radius: Theme.px(16)
                color: scMa.containsMouse ? Theme.cardHover : Theme.card
                scale: scMa.pressed ? 0.94 : 1.0
                Behavior on scale { Spring { epsilon: 0.002 } }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(6)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "screenshot_region"
                        size: Theme.px(16)
                        color: Theme.text
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Скрин [S]"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
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
