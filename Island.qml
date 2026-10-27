import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// «Чёлка» на каждом мониторе.
// Режимы:
//   compact  — рабочие столы · время · раскладка
//   osd      — плашка на ~1.5с при смене громкости или раскладки
//   expanded — клик: дата, плеер, громкость, CPU / RAM
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)

    anchors.top: true
    implicitWidth: Theme.expandedW + 2 * Theme.notchFillet + 40
    implicitHeight: 520
    color: "transparent"

    // место резервируется только под свёрнутую чёлку — раскрытая рисуется поверх окон
    exclusiveZone: Theme.compactH
    WlrLayershell.namespace: "dynamic-island"
    WlrLayershell.layer: WlrLayer.Top
    // клики проходят сквозь прозрачную часть окна
    mask: Region { item: notch }

    // ───────── Состояние ─────────
    property bool expanded: false
    property string osd: ""            // "", "volume", "layout"
    property string lastOsd: "volume"  // что рисовать, пока плашка исчезает
    readonly property string mode: expanded ? "expanded" : osd !== "" ? "osd" : "compact"

    function showOsd(kind) {
        if (expanded || !armed) return;
        if (monitor && !monitor.focused) return;   // только на активном мониторе
        lastOsd = kind;
        osd = kind;
        osdTimer.restart();
    }
    function toggle() {
        osd = "";
        expanded = !expanded;
    }

    // не показываем плашку на значениях, пришедших при запуске
    property bool armed: false
    Timer { interval: 1500; running: true; onTriggered: win.armed = true }
    Timer { id: osdTimer; interval: Theme.osdMs; onTriggered: win.osd = "" }
    Timer { id: collapseTimer; interval: 550; onTriggered: win.expanded = false }

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
        target: IslandIpc
        function onToggleRequested() {
            if (win.monitor && !win.monitor.focused) return;
            win.toggle();
        }
        function onCloseRequested() { win.expanded = false; }
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // ширина компактной чёлки — симметричная, чтобы время было ровно по центру
    readonly property real sideW: Math.max(wsCompact.implicitWidth, layoutBadge.width)
    readonly property real compactW: 2 * sideW + clockText.implicitWidth + 2 * 12 + 2 * 15

    // ───────── Чёлка ─────────
    Item {
        id: notch

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: bw + 2 * Theme.notchFillet
        height: bh

        // целевые размеры по режиму; пружина догоняет их
        property real bw: win.mode === "expanded" ? Theme.expandedW
                        : win.mode === "osd" ? Theme.osdW : win.compactW
        property real bh: win.mode === "expanded" ? expandedView.implicitHeight + 2 * Theme.pad
                        : win.mode === "osd" ? Theme.osdH : Theme.compactH
        property real rad: win.mode === "expanded" ? Theme.expandedRadius : Theme.compactRadius
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
            onHoveredChanged: {
                if (hovered) collapseTimer.stop();
                else if (win.expanded) collapseTimer.restart();
            }
        }

        // Тело чёлки (всё содержимое обрезается по нему)
        Item {
            id: body
            x: Theme.notchFillet
            width: notch.bw
            height: notch.bh
            clip: true

            // Фон: клик — раскрыть/свернуть, колесо — листать рабочие столы
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property real acc: 0
                onClicked: win.toggle()
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
                width: win.compactW
                height: Theme.compactH
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                Workspaces {
                    id: wsCompact
                    monitor: win.monitor
                    anchors.left: parent.left
                    anchors.leftMargin: 15
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatTime(clock.date, "HH:mm")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }

                // раскладка: клик — переключить
                Rectangle {
                    id: layoutBadge
                    visible: Keyboard.short !== ""
                    anchors.right: parent.right
                    anchors.rightMargin: 15
                    anchors.verticalCenter: parent.verticalCenter
                    width: layoutText.implicitWidth + 9
                    height: 16
                    radius: 5
                    color: "transparent"
                    border.width: 1.2
                    border.color: Theme.text2
                    Text {
                        id: layoutText
                        anchors.centerIn: parent
                        text: Keyboard.short
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Keyboard.next()
                    }
                }
            }

            // ═════════ OSD ═════════
            MorphView {
                id: osdView
                shown: win.mode === "osd"
                width: Theme.osdW
                height: Theme.osdH
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                // громкость
                Item {
                    anchors.fill: parent
                    visible: win.lastOsd === "volume"

                    Icon {
                        id: osdVolIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        name: Audio.icon
                        size: 20
                        color: Audio.muted ? Theme.red : Theme.text
                    }
                    Bar {
                        anchors.left: osdVolIcon.right
                        anchors.right: osdVolText.left
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        height: 6
                        value: Audio.muted ? 0 : Audio.volume
                        tint: Theme.text
                    }
                    Text {
                        id: osdVolText
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        horizontalAlignment: Text.AlignRight
                        text: Audio.muted ? "off" : Math.round(Audio.volume * 100)
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                }

                // раскладка
                Item {
                    anchors.fill: parent
                    visible: win.lastOsd === "layout"

                    Icon {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        name: "keyboard"
                        size: 22
                        color: Theme.blue
                    }
                    Text {
                        anchors.centerIn: parent
                        text: Keyboard.layout
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: Keyboard.short
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                }
            }

            // ═════════ EXPANDED (дашборд) ═════════
            MorphView {
                id: expandedWrap
                shown: win.mode === "expanded"
                hiddenScale: 0.9
                transformOrigin: Item.Top
                width: Theme.expandedW - 2 * Theme.pad
                height: expandedView.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.pad

                Column {
                    id: expandedView
                    width: parent.width
                    spacing: 10

                    // Шапка: время, дата, рабочие столы
                    Item {
                        width: parent.width
                        height: 50

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatTime(clock.date, "HH:mm")
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 38
                                font.weight: Font.Bold
                                font.features: { "tnum": 1 }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    text: clock.date.toLocaleDateString(Qt.locale("ru_RU"), "dddd")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    font.capitalization: Font.Capitalize
                                }
                                Text {
                                    text: clock.date.toLocaleDateString(Qt.locale("ru_RU"), "d MMMM")
                                    color: Theme.text2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                }
                            }
                        }

                        Column {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Workspaces {
                                anchors.right: parent.right
                                monitor: win.monitor
                                dot: 8
                                activeW: 24
                                spacing: 6
                            }
                            Text {
                                anchors.right: parent.right
                                text: "Рабочий стол " + (win.monitor?.activeWorkspace?.id ?? "")
                                      + (Keyboard.layout ? "  ·  " + Keyboard.short : "")
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }
                    }

                    // Плеер (только если что-то открыто)
                    MediaCard {
                        width: parent.width
                        visible: Media.player !== null
                    }

                    // Громкость — большая карточка
                    VolumeCard {
                        width: parent.width
                    }

                    // CPU / RAM
                    Row {
                        width: parent.width
                        spacing: 10
                        readonly property real tileW: (width - spacing) / 2

                        StatTile {
                            width: parent.tileW
                            icon: "memory"
                            label: "Процессор" + (SysInfo.cpuTemp >= 0 ? " · " + SysInfo.cpuTemp + "°" : "")
                            value: Math.round(SysInfo.cpu * 100) + "%"
                            level: SysInfo.cpu
                            tint: SysInfo.cpu > 0.85 ? Theme.red : SysInfo.cpu > 0.6 ? Theme.orange : Theme.blue
                        }
                        StatTile {
                            width: parent.tileW
                            icon: "memory_alt"
                            label: "Память · " + SysInfo.memTotalGb.toFixed(0) + " ГБ"
                            value: SysInfo.memUsedGb.toFixed(1) + " ГБ"
                            level: SysInfo.mem
                            tint: SysInfo.mem > 0.85 ? Theme.red : Theme.purple
                        }
                    }
                }
            }
        }
    }
}
