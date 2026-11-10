import QtQuick
import qs.services
import qs.components

// Interactive Timer panel with animated horizontal tick ruler and dual states (Idle / Running).
// Hotkeys: Space/Enter — start/pause, R/Escape/Backspace — reset, Left/Right/Up/Down — adjust minutes.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true

    implicitWidth: Theme.px(350)
    implicitHeight: card.height

    readonly property color accentOrange: "#FF9F0A"
    readonly property color dimOrange: Qt.rgba(1.0, 0.62, 0.04, 0.20)
    readonly property color btnBg: "#362511"
    readonly property color btnBgHover: "#483116"
    readonly property color pauseBtnBg: "#543A1B"
    readonly property color pauseBtnBgHover: "#694821"

    // Target minutes shown at the center pointer of the ruler
    readonly property real targetMin: Timers.running
        ? (Timers.remainSec / 60.0)
        : Math.round(Timers.totalSec / 60.0)

    property real displayMin: targetMin
    Behavior on displayMin {
        Spring {
            spring: 5.2
            damping: 0.48
            epsilon: 0.005
        }
    }

    onDisplayMinChanged: rulerCanvas.requestPaint()

    Connections {
        target: Timers
        function onRunningChanged() {
            rulerCanvas.requestPaint();
            pointerCanvas.requestPaint();
        }
        function onPausedChanged() {
            rulerCanvas.requestPaint();
        }
    }

    Component.onCompleted: {
        Timers.mode = "timer";
        rulerCanvas.requestPaint();
        pointerCanvas.requestPaint();
    }

    Keys.onPressed: event => {
        const t = (event.text || "").toLowerCase();
        const step = (event.modifiers & Qt.ShiftModifier) ? 300 : 60;
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            Timers.toggleStart();
            event.accepted = true;
        } else if (event.key === Qt.Key_R || t === "r" || t === "к" || (Timers.running && event.key === Qt.Key_X)) {
            Timers.reset();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            if (!Timers.running) {
                Timers.setPreset(Timers.totalSec + step);
            } else {
                Timers.addSeconds(step);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Down || event.key === Qt.Key_Minus) {
            if (!Timers.running) {
                Timers.setPreset(Math.max(60, Timers.totalSec - step));
            } else {
                Timers.addSeconds(-step);
            }
            event.accepted = true;
        }
    }

    Rectangle {
        id: card
        width: parent.width
        height: Theme.px(196)
        radius: Theme.px(26)
        color: "#15120E"
        border.width: 1
        border.color: Qt.rgba(1.0, 0.62, 0.04, 0.14)

        // ── Top Section: Interactive Horizontal Tick Ruler ──
        Item {
            id: rulerArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Theme.px(14)
            anchors.leftMargin: Theme.px(14)
            anchors.rightMargin: Theme.px(14)
            height: Theme.px(96)

            Canvas {
                id: rulerCanvas
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Theme.px(68)
                renderTarget: Canvas.FramebufferObject
                renderStrategy: Canvas.Threaded

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    const cx = width / 2;
                    const stepPx = Theme.px(11);
                    const cur = root.displayMin;
                    const activeThreshold = Timers.running ? Math.ceil(cur - 0.02) : Math.round(cur);

                    const minM = Math.max(0, Math.floor(cur - (cx / stepPx) - 2));
                    const maxM = Math.min(120, Math.ceil(cur + (cx / stepPx) + 2));

                    const labelY = Theme.px(15);
                    const tickTop = Theme.px(26);
                    const tickBottom = Theme.px(60);
                    const tickW = Math.max(2, Theme.px(2.4));

                    ctx.textAlign = "center";
                    ctx.textBaseline = "middle";
                    ctx.font = "bold " + Theme.px(13) + "px '" + Theme.fontFamily + "'";

                    for (let m = minM; m <= maxM; m++) {
                        const x = cx + (m - cur) * stepPx;
                        if (x < -stepPx || x > width + stepPx) continue;

                        // Smooth fade near horizontal edges
                        const distFromEdge = Math.min(x, width - x);
                        const edgeFade = Math.max(0, Math.min(1, distFromEdge / Theme.px(32)));
                        if (edgeFade <= 0.01) continue;

                        // Active ticks (left of or at current minute) are bright orange; right of pointer are dimmed
                        const isLit = Timers.running
                            ? (m <= activeThreshold && (cur > 0.01 || m === 0))
                            : (m <= activeThreshold);

                        const baseAlpha = isLit ? 0.96 : 0.19;
                        const alpha = baseAlpha * edgeFade;

                        // Draw 5-minute number labels (0, 5, 10, 15, 20...)
                        if (m % 5 === 0) {
                            const labelAlpha = (isLit ? 0.95 : 0.24) * edgeFade;
                            ctx.fillStyle = "rgba(255, 159, 10, " + labelAlpha.toFixed(3) + ")";
                            ctx.fillText(String(m), x, labelY);
                        }

                        // Draw vertical tick bar
                        ctx.fillStyle = "rgba(255, 159, 10, " + alpha.toFixed(3) + ")";
                        const r = tickW / 2;
                        const bx = x - r;
                        const bh = tickBottom - tickTop;
                        ctx.beginPath();
                        ctx.roundedRect(bx, tickTop, tickW, bh, r, r);
                        ctx.fill();
                    }
                }
            }

            // Center pointer symbol below ticks (▲ in idle, ⏏ with underline when running)
            Canvas {
                id: pointerCanvas
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.px(2)
                width: Theme.px(18)
                height: Theme.px(16)
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = "#FF9F0A";

                    const cx = width / 2;
                    const triTop = Theme.px(1);
                    const triBottom = Timers.running ? Theme.px(10) : Theme.px(11);
                    const halfW = Theme.px(5.5);

                    ctx.beginPath();
                    ctx.moveTo(cx, triTop);
                    ctx.lineTo(cx - halfW, triBottom);
                    ctx.lineTo(cx + halfW, triBottom);
                    ctx.closePath();
                    ctx.fill();

                    if (Timers.running) {
                        const barY = Theme.px(12.5);
                        const barH = Math.max(1.5, Theme.px(2));
                        ctx.fillRect(cx - halfW, barY, halfW * 2, barH);
                    }
                }
            }

            // Interactive Drag & Wheel Scrubbing Area
            MouseArea {
                id: scrubArea
                anchors.fill: parent
                cursorShape: Timers.running ? Qt.ArrowCursor : Qt.SizeHorCursor
                property real startX: 0
                property int startMin: 15
                property bool dragged: false

                onPressed: mouse => {
                    if (Timers.running) return;
                    startX = mouse.x;
                    startMin = Math.round(Timers.totalSec / 60);
                    dragged = false;
                }

                onPositionChanged: mouse => {
                    if (!pressed || Timers.running) return;
                    const dx = mouse.x - startX;
                    if (Math.abs(dx) > Theme.px(3)) dragged = true;
                    const stepPx = Theme.px(11);
                    const deltaMin = -Math.round(dx / stepPx);
                    const nextMin = Math.max(1, Math.min(120, startMin + deltaMin));
                    if (nextMin * 60 !== Timers.totalSec) {
                        Timers.setPreset(nextMin * 60);
                    }
                }

                onReleased: mouse => {
                    if (Timers.running || dragged) return;
                    // Click on ruler jumps to clicked minute
                    const cx = width / 2;
                    const stepPx = Theme.px(11);
                    const clickedOffset = Math.round((mouse.x - cx) / stepPx);
                    if (clickedOffset !== 0) {
                        const curMin = Math.round(Timers.totalSec / 60);
                        const nextMin = Math.max(1, Math.min(120, curMin + clickedOffset));
                        Timers.setPreset(nextMin * 60);
                    }
                }

                onWheel: w => {
                    const delta = w.angleDelta.y > 0 ? 60 : -60;
                    if (!Timers.running) {
                        Timers.setPreset(Math.max(60, Math.min(7200, Timers.totalSec + delta)));
                    } else {
                        Timers.addSeconds(delta);
                    }
                }
            }
        }

        // ── Bottom Section: Controls (Left) + Large Countdown Display (Right) ──
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.px(20)
            anchors.rightMargin: Theme.px(20)
            anchors.bottomMargin: Theme.px(18)
            height: Theme.px(56)

            // State 1: "Start Timer" pill button (when !Timers.running)
            Rectangle {
                id: startBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(142)
                height: Theme.px(48)
                radius: height / 2
                color: startMa.containsMouse ? root.btnBgHover : root.btnBg
                opacity: Timers.running ? 0.0 : 1.0
                visible: opacity > 0.01
                scale: Timers.running ? 0.85 : (startMa.pressed ? 0.94 : (startMa.containsMouse ? 1.03 : 1.0))

                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on scale { Spring { spring: 5.0; damping: 0.45; epsilon: 0.01 } }
                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.centerIn: parent
                    text: "Start Timer"
                    color: root.accentOrange
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(14)
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: startMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !Timers.running
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Timers.toggleStart()
                }
            }

            // State 2: Cancel (✕) and Pause/Resume (⏸/▶) circular buttons (when Timers.running)
            Row {
                id: runningBtns
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(12)
                opacity: Timers.running ? 1.0 : 0.0
                visible: opacity > 0.01
                scale: Timers.running ? 1.0 : 0.85

                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on scale { Spring { spring: 5.0; damping: 0.45; epsilon: 0.01 } }

                // Cancel / Reset Button (✕)
                Rectangle {
                    width: Theme.px(50)
                    height: width
                    radius: width / 2
                    color: cancelMa.containsMouse ? root.btnBgHover : root.btnBg
                    scale: cancelMa.pressed ? 0.90 : (cancelMa.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { Spring { epsilon: 0.01 } }
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Icon {
                        anchors.centerIn: parent
                        name: "close"
                        size: Theme.px(20)
                        color: root.accentOrange
                    }

                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: Timers.running
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Timers.reset()
                    }
                }

                // Pause / Play Button (⏸ / ▶)
                Rectangle {
                    width: Theme.px(50)
                    height: width
                    radius: width / 2
                    color: pauseMa.containsMouse ? root.pauseBtnBgHover : root.pauseBtnBg
                    scale: pauseMa.pressed ? 0.90 : (pauseMa.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { Spring { epsilon: 0.01 } }
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Icon {
                        anchors.centerIn: parent
                        name: Timers.paused ? "play_arrow" : "pause"
                        size: Theme.px(22)
                        color: root.accentOrange
                    }

                    MouseArea {
                        id: pauseMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: Timers.running
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Timers.toggleStart()
                    }
                }
            }

            // Large Digital Time Display on the Right (22:00 / 00:54)
            Text {
                id: timeReadout
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Timers.display
                color: root.accentOrange
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(44)
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                opacity: Timers.paused ? 0.65 : 1.0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Timers.toggleStart()
                    onWheel: w => {
                        const delta = w.angleDelta.y > 0 ? 60 : -60;
                        if (!Timers.running) {
                            Timers.setPreset(Math.max(60, Math.min(7200, Timers.totalSec + delta)));
                        } else {
                            Timers.addSeconds(delta);
                        }
                    }
                }
            }
        }
    }
}
