import QtQuick
import qs.services
import qs.components

// Панель таймера и секундомера. Клавиши: Space/Enter — старт/пауза, R — сброс, M — режим, +/Up — +1 мин.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    implicitHeight: row.implicitHeight

    Connections {
        target: Timers
        function onProgressChanged() { ringCanvas.requestPaint(); }
        function onModeChanged() { ringCanvas.requestPaint(); }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            Timers.toggleStart();
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            Timers.reset();
            event.accepted = true;
        } else if (event.key === Qt.Key_M) {
            Timers.running = false;
            Timers.paused = false;
            Timers.mode = (Timers.mode === "timer" ? "stopwatch" : "timer");
            event.accepted = true;
        } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal || event.key === Qt.Key_Up) {
            Timers.addSeconds(60);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            Timers.addSeconds(-60);
            event.accepted = true;
        }
    }

    Row {
        id: row
        width: parent.width
        spacing: Theme.px(10)

        // Левая карточка — кольцо с отсчётом (колесо мыши меняет время, клик — старт/пауза)
        Rectangle {
            width: Theme.px(196)
            height: Theme.px(164)
            radius: Theme.px(20)
            color: Theme.card

            Canvas {
                id: ringCanvas
                anchors.centerIn: parent
                width: Theme.px(128)
                height: width
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const c = width / 2, lw = Theme.px(7), r = c - lw;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.10);
                    ctx.beginPath();
                    ctx.arc(c, c, r, 0, Math.PI * 2);
                    ctx.stroke();

                    if (Timers.progress > 0.005) {
                        ctx.strokeStyle = "#FF9F0A";
                        ctx.beginPath();
                        ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Timers.progress);
                        ctx.stroke();
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.px(2)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Timers.display
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(24)
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Timers.mode === "timer" ? "ТАЙМЕР" : "СЕКУНДОМЕР"
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

        // Правая карточка — пресеты и управление
        Rectangle {
            width: parent.width - Theme.px(206)
            height: Theme.px(164)
            radius: Theme.px(20)
            color: Theme.card

            Column {
                anchors.fill: parent
                anchors.margins: Theme.px(14)
                spacing: Theme.px(11)

                // Переключатель режима: Таймер / Секундомер [M]
                Row {
                    spacing: Theme.px(8)
                    Repeater {
                        model: [
                            { key: "timer", label: "Таймер", icon: "timer" },
                            { key: "stopwatch", label: "Секундомер [M]", icon: "timer_play" }
                        ]
                        Rectangle {
                            id: mTab
                            required property var modelData
                            readonly property bool active: Timers.mode === modelData.key
                            height: Theme.px(30)
                            width: mRow.implicitWidth + Theme.px(20)
                            radius: height / 2
                            color: active ? Theme.orange : Qt.rgba(1, 1, 1, 0.08)

                            Row {
                                id: mRow
                                anchors.centerIn: parent
                                spacing: Theme.px(5)
                                Icon {
                                    name: mTab.modelData.icon
                                    size: Theme.px(15)
                                    color: mTab.active ? "black" : Theme.text
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: mTab.modelData.label
                                    color: mTab.active ? "black" : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(12)
                                    font.weight: Font.Bold
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
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

                // Быстрые пресеты (для таймера)
                Row {
                    visible: Timers.mode === "timer"
                    width: parent.width
                    spacing: Theme.px(6)
                    readonly property real chipW: (width - 6 * spacing) / 7

                    Repeater {
                        model: [
                            { label: "1м", sec: 60 },
                            { label: "3м", sec: 180 },
                            { label: "5м", sec: 300 },
                            { label: "10м", sec: 600 },
                            { label: "15м", sec: 900 },
                            { label: "25м", sec: 1500 },
                            { label: "+1м", sec: -1 }
                        ]
                        Rectangle {
                            id: pChip
                            required property var modelData
                            height: Theme.px(32)
                            width: parent.chipW
                            radius: Theme.px(10)
                            color: (Timers.totalSec === modelData.sec && modelData.sec > 0)
                                   ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.07)

                            Text {
                                id: pTxt
                                anchors.centerIn: parent
                                text: pChip.modelData.label
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (pChip.modelData.sec === -1) Timers.addSeconds(60);
                                    else Timers.setPreset(pChip.modelData.sec);
                                }
                            }
                        }
                    }
                }

                // Кнопки Старт / Пауза [Space] и Сброс [R]
                Row {
                    spacing: Theme.px(10)

                    Rectangle {
                        width: Theme.px(150)
                        height: Theme.px(38)
                        radius: height / 2
                        color: Timers.running && !Timers.paused ? Theme.orange : Theme.green
                        scale: stMa.pressed ? 0.93 : 1.0
                        Behavior on scale { Spring {} }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.px(6)
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: Timers.running && !Timers.paused ? "pause" : "play_arrow"
                                size: Theme.px(18)
                                color: "black"
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: !Timers.running ? "Старт [␣]" : (Timers.paused ? "Продолжить" : "Пауза [␣]")
                                color: "black"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.Bold
                            }
                        }
                        MouseArea {
                            id: stMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Timers.toggleStart()
                        }
                    }

                    Rectangle {
                        width: Theme.px(112)
                        height: Theme.px(38)
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.1)
                        Text {
                            anchors.centerIn: parent
                            text: "Сброс [R]"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: parentMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Timers.reset()
                        }
                    }
                }
            }
        }
    }
}
