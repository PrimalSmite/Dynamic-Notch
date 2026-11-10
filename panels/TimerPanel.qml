import QtQuick
import qs.services
import qs.components

// Timer and stopwatch panel: compact vertical widget for Dynamic Notch.
// Hotkeys: Space/Enter — start/pause, R — reset, M — mode, +/Up — +1 min, -/Down — -1 min.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true

    implicitWidth: Theme.px(360)
    implicitHeight: col.implicitHeight

    Connections {
        target: Timers
        function onProgressChanged() { ringCanvas.requestPaint(); }
        function onModeChanged() { ringCanvas.requestPaint(); }
    }

    Keys.onPressed: event => {
        const t = (event.text || "").toLowerCase();
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            Timers.toggleStart();
            event.accepted = true;
        } else if (event.key === Qt.Key_R || t === "r" || t === "к") {
            Timers.reset();
            event.accepted = true;
        } else if (event.key === Qt.Key_M || t === "m" || t === "ь") {
            Timers.running = false;
            Timers.paused = false;
            Timers.mode = (Timers.mode === "timer" ? "stopwatch" : "timer");
            event.accepted = true;
        } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal || event.key === Qt.Key_Up) {
            Timers.addSeconds(60);
            event.accepted = true;
        } else if (event.key === Qt.Key_Minus || event.key === Qt.Key_Down) {
            Timers.addSeconds(-60);
            event.accepted = true;
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        // 1. Mode selector: Timer / Stopwatch [M]
        Row {
            width: parent.width
            spacing: Theme.px(8)
            readonly property real tabW: (width - spacing) / 2

            Repeater {
                model: [
                    { key: "timer", label: "Timer", icon: "timer" },
                    { key: "stopwatch", label: "Stopwatch [M]", icon: "timer_play" }
                ]
                Rectangle {
                    id: mTab
                    required property var modelData
                    readonly property bool active: Timers.mode === modelData.key
                    height: Theme.px(32)
                    width: parent.tabW
                    radius: Theme.px(10)
                    color: active ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.08)
                    scale: mTabMa.pressed ? 0.94 : (mTabMa.containsMouse ? 1.02 : 1.0)
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on scale { Spring { epsilon: 0.01 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(6)
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: mTab.modelData.icon
                            size: Theme.px(15)
                            color: mTab.active ? "black" : Theme.text2
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: mTab.modelData.label
                            color: mTab.active ? "black" : Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.DemiBold
                        }
                    }
                    MouseArea {
                        id: mTabMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Timers.running = false;
                            Timers.paused = false;
                            Timers.mode = mTab.modelData.key;
                        }
                    }
                }
            }
        }

        // 2. Center card with circular time indicator
        Rectangle {
            width: parent.width
            height: Theme.px(160)
            radius: Theme.px(20)
            color: Theme.card

            Canvas {
                id: ringCanvas
                anchors.centerIn: parent
                width: Theme.px(130)
                height: width
                renderTarget: Canvas.FramebufferObject
                renderStrategy: Canvas.Threaded
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const c = width / 2, lw = Theme.px(7), r = c - lw;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "round";

                    // Track background
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.10);
                    ctx.beginPath();
                    ctx.arc(c, c, r, 0, Math.PI * 2);
                    ctx.stroke();

                    // Active progress arc
                    if (Timers.progress > 0.005) {
                        const isUrgent = Timers.mode === "timer" && Timers.totalSec > 0 && (Timers.totalSec * (1 - Timers.progress) <= 10);
                        ctx.strokeStyle = isUrgent ? "#FF453A" : (Timers.paused ? Qt.rgba(1, 1, 1, 0.40) : "#FFFFFF");
                        ctx.beginPath();
                        ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Timers.progress);
                        ctx.stroke();
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.px(2)

                    RollingClock {
                        anchors.horizontalCenter: parent.horizontalCenter
                        timeString: Timers.display
                        fontSize: Theme.px(26)
                        fontWeight: Font.Bold
                        textColor: Theme.controlFill
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Timers.mode === "timer" ? "TIMER" : "STOPWATCH"
                        color: Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(9)
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Timers.toggleStart()
                onWheel: w => {
                    if (Timers.mode === "timer")
                        Timers.addSeconds(w.angleDelta.y > 0 ? 60 : -60);
                }
            }
        }

        // 3. Quick timer presets grid (2 rows of 4 pills)
        Column {
            visible: Timers.mode === "timer"
            width: parent.width
            spacing: Theme.px(6)

            readonly property var presetsRow1: [
                { label: "1 min", sec: 60 },
                { label: "3 min", sec: 180 },
                { label: "5 min", sec: 300 },
                { label: "10 min", sec: 600 }
            ]

            readonly property var presetsRow2: [
                { label: "15 min", sec: 900 },
                { label: "25 min", sec: 1500 },
                { label: "30 min", sec: 1800 },
                { label: "+1 min", sec: -1 }
            ]

            Row {
                width: parent.width
                spacing: Theme.px(6)
                readonly property real chipW: (width - 3 * spacing) / 4

                Repeater {
                    model: parent.parent.presetsRow1
                    Rectangle {
                        id: pChip1
                        required property var modelData
                        height: Theme.px(28)
                        width: parent.chipW
                        radius: Theme.px(9)
                        color: (Timers.totalSec === modelData.sec && modelData.sec > 0)
                               ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.07)
                        scale: pChipMa1.pressed ? 0.92 : (pChipMa1.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { Spring { epsilon: 0.01 } }

                        Text {
                            anchors.centerIn: parent
                            text: pChip1.modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: pChipMa1
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (pChip1.modelData.sec === -1) Timers.addSeconds(60);
                                else Timers.setPreset(pChip1.modelData.sec);
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.px(6)
                readonly property real chipW: (width - 3 * spacing) / 4

                Repeater {
                    model: parent.parent.presetsRow2
                    Rectangle {
                        id: pChip2
                        required property var modelData
                        height: Theme.px(28)
                        width: parent.chipW
                        radius: Theme.px(9)
                        color: (Timers.totalSec === modelData.sec && modelData.sec > 0)
                               ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.07)
                        scale: pChipMa2.pressed ? 0.92 : (pChipMa2.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { Spring { epsilon: 0.01 } }

                        Text {
                            anchors.centerIn: parent
                            text: pChip2.modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: pChipMa2
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (pChip2.modelData.sec === -1) Timers.addSeconds(60);
                                else Timers.setPreset(pChip2.modelData.sec);
                            }
                        }
                    }
                }
            }
        }

        // 4. Main control buttons: Start / Pause [␣] and Reset [R]
        Row {
            width: parent.width
            spacing: Theme.px(8)

            // Start / Pause button
            Rectangle {
                width: parent.width * 0.64 - Theme.px(4)
                height: Theme.px(40)
                radius: height / 2
                color: Timers.running && !Timers.paused ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.12)
                scale: stMa.pressed ? 0.93 : (stMa.containsMouse ? 1.03 : 1.0)
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on scale { Spring { epsilon: 0.01 } }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(7)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Timers.running && !Timers.paused ? "pause" : "play_arrow"
                        size: Theme.px(18)
                        color: Timers.running && !Timers.paused ? "black" : Theme.controlFill
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: !Timers.running ? "Start [␣]" : (Timers.paused ? "Resume" : "Pause [␣]")
                        color: Timers.running && !Timers.paused ? "black" : Theme.controlFill
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(13)
                        font.weight: Font.Bold
                    }
                }
                MouseArea {
                    id: stMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Timers.toggleStart()
                }
            }

            // Reset button
            Rectangle {
                width: parent.width * 0.36 - Theme.px(4)
                height: Theme.px(40)
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.08)
                scale: rstMa.pressed ? 0.93 : (rstMa.containsMouse ? 1.03 : 1.0)
                Behavior on scale { Spring { epsilon: 0.01 } }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(5)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "restart_alt"
                        size: Theme.px(15)
                        color: Theme.text2
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Reset [R]"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: rstMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Timers.reset()
                }
            }
        }
    }
}
