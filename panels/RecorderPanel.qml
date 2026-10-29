import QtQuick
import Quickshell
import qs.services
import qs.components

// Панель записи экрана: компактный вертикальный виджет для Dynamic Notch.
// Клавиши: Enter/Space — старт/стоп, S/G — экран/область, A/M/C/F — опции.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true

    implicitWidth: Theme.px(380)
    implicitHeight: col.implicitHeight

    function toggleRec() {
        if (Recorder.recording) {
            Recorder.stop();
        } else {
            const mon = (root.host && root.host.monitor && root.host.monitor.name) ? root.host.monitor.name : "screen";
            if (root.host) root.host.collapse();
            Recorder.start(mon);
        }
    }

    Keys.onPressed: event => {
        const t = (event.text || "").toLowerCase();
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            toggleRec();
            event.accepted = true;
        } else if (!Recorder.recording) {
            if (event.key === Qt.Key_S || t === "s" || t === "ы") { Recorder.target = "screen"; event.accepted = true; }
            else if (event.key === Qt.Key_G || t === "g" || t === "п") { Recorder.target = "region"; event.accepted = true; }
            else if (event.key === Qt.Key_A || t === "a" || t === "ф") { Recorder.audioDesktop = !Recorder.audioDesktop; event.accepted = true; }
            else if (event.key === Qt.Key_M || t === "m" || t === "ь") { Recorder.audioMic = !Recorder.audioMic; event.accepted = true; }
            else if (event.key === Qt.Key_C || t === "c" || t === "с") { Recorder.showCursor = !Recorder.showCursor; event.accepted = true; }
            else if (event.key === Qt.Key_F || t === "f" || t === "а") { Recorder.fps = (Recorder.fps === 60 ? 30 : 60); event.accepted = true; }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        // 1. Выбор цели записи: Весь экран [S] / Область [G]
        Row {
            width: parent.width
            spacing: Theme.px(8)
            readonly property real tabW: (width - spacing) / 2

            Repeater {
                model: [
                    { key: "screen", label: "Весь экран [S]", icon: "desktop_windows" },
                    { key: "region", label: "Область [G]", icon: "crop_free" }
                ]
                Rectangle {
                    id: tgtBtn
                    required property var modelData
                    readonly property bool active: Recorder.target === modelData.key
                    width: parent.tabW
                    height: Theme.px(36)
                    radius: Theme.px(11)
                    color: active ? Theme.controlFill : Qt.rgba(1, 1, 1, 0.08)
                    scale: tgtMa.pressed ? 0.94 : (tgtMa.containsMouse ? 1.02 : 1.0)
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on scale { Spring { epsilon: 0.01 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(6)
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: tgtBtn.modelData.icon
                            size: Theme.px(16)
                            color: tgtBtn.active ? "black" : Theme.text2
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tgtBtn.modelData.label
                            color: tgtBtn.active ? "black" : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.DemiBold
                        }
                    }
                    MouseArea {
                        id: tgtMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !Recorder.recording
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Recorder.target = tgtBtn.modelData.key
                    }
                }
            }
        }

        // 2. Сетка опций записи 2×2: Звук, Микрофон, Курсор, FPS
        Column {
            width: parent.width
            spacing: Theme.px(6)

            readonly property var optRow1: [
                { key: "audio", icon: "volume_up", label: "Звук системы [A]", on: Recorder.audioDesktop },
                { key: "mic", icon: "mic", label: "Микрофон [M]", on: Recorder.audioMic }
            ]
            readonly property var optRow2: [
                { key: "cursor", icon: "mouse", label: "Курсор [C]", on: Recorder.showCursor },
                { key: "fps", icon: "speed", label: Recorder.fps + " FPS [F]", on: Recorder.fps === 60 }
            ]

            function toggleKey(k) {
                if (k === "audio") Recorder.audioDesktop = !Recorder.audioDesktop;
                else if (k === "mic") Recorder.audioMic = !Recorder.audioMic;
                else if (k === "cursor") Recorder.showCursor = !Recorder.showCursor;
                else if (k === "fps") Recorder.fps = (Recorder.fps === 60 ? 30 : 60);
            }

            Row {
                width: parent.width
                spacing: Theme.px(6)
                readonly property real chipW: (width - spacing) / 2

                Repeater {
                    model: parent.parent.optRow1
                    Rectangle {
                        id: oChip1
                        required property var modelData
                        width: parent.chipW
                        height: Theme.px(38)
                        radius: Theme.px(11)
                        color: modelData.on ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                        scale: oMa1.pressed ? 0.94 : (oMa1.containsMouse ? 1.02 : 1.0)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on scale { Spring { epsilon: 0.01 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.px(7)
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: oChip1.modelData.icon
                                size: Theme.px(15)
                                color: oChip1.modelData.on ? Theme.controlFill : Theme.text3
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: oChip1.modelData.label
                                color: oChip1.modelData.on ? Theme.text : Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.Medium
                            }
                        }
                        MouseArea {
                            id: oMa1
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !Recorder.recording
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.parent.parent.toggleKey(oChip1.modelData.key)
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.px(6)
                readonly property real chipW: (width - spacing) / 2

                Repeater {
                    model: parent.parent.optRow2
                    Rectangle {
                        id: oChip2
                        required property var modelData
                        width: parent.chipW
                        height: Theme.px(38)
                        radius: Theme.px(11)
                        color: modelData.on ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                        scale: oMa2.pressed ? 0.94 : (oMa2.containsMouse ? 1.02 : 1.0)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on scale { Spring { epsilon: 0.01 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.px(7)
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: oChip2.modelData.icon
                                size: Theme.px(15)
                                color: oChip2.modelData.on ? Theme.controlFill : Theme.text3
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: oChip2.modelData.label
                                color: oChip2.modelData.on ? Theme.text : Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.Medium
                            }
                        }
                        MouseArea {
                            id: oMa2
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !Recorder.recording
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.parent.parent.toggleKey(oChip2.modelData.key)
                        }
                    }
                }
            }
        }

        // 3. Основная кнопка записи / остановки
        Rectangle {
            width: parent.width
            height: Theme.px(44)
            radius: height / 2
            color: Recorder.recording ? Theme.controlFill : Theme.alert
            scale: recMa.pressed ? 0.94 : (recMa.containsMouse ? 1.02 : 1.0)
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on scale { Spring { epsilon: 0.01 } }

            Row {
                anchors.centerIn: parent
                spacing: Theme.px(8)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Recorder.recording ? "stop" : "fiber_manual_record"
                    size: Theme.px(18)
                    color: Recorder.recording ? Theme.alert : "white"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Recorder.recording ? ("Остановить запись · " + Recorder.elapsedText) : "Начать запись [↵]"
                    color: Recorder.recording ? "black" : "white"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(13)
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                }
            }

            MouseArea {
                id: recMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleRec()
            }
        }

        // 4. Карточка последней записи (если есть)
        Rectangle {
            visible: Recorder.recentFiles.length > 0
            width: parent.width
            height: Theme.px(38)
            radius: Theme.px(12)
            color: Theme.card

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(12)
                anchors.rightMargin: Theme.px(12)
                spacing: Theme.px(8)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "folder_open"
                    size: Theme.px(16)
                    color: Theme.text3
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Recorder.recentFiles[0] ? Recorder.recentFiles[0].split("/").pop() : ""
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                    elide: Text.ElideRight
                    width: parent.width - Theme.px(110)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Открыть →"
                    color: Theme.controlFill
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                    font.weight: Font.DemiBold
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Recorder.recentFiles[0])
                                Quickshell.execDetached(["xdg-open", Recorder.recentFiles[0]]);
                        }
                    }
                }
            }
        }
    }
}
