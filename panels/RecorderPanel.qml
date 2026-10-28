import QtQuick
import Quickshell
import qs.services
import qs.components

// Панель записи экрана (gpu-screen-recorder). Клавиши: Enter/Space — старт/стоп, S/G — экран/область, A/M/C/F — опции.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    implicitHeight: col.implicitHeight

    function toggleRec() {
        if (Recorder.recording) {
            Recorder.stop();
        } else {
            const mon = root.host?.monitor?.name || "screen";
            Recorder.start(mon);
            if (root.host) root.host.collapse();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            toggleRec();
            event.accepted = true;
        } else if (!Recorder.recording) {
            if (event.key === Qt.Key_S) { Recorder.target = "screen"; event.accepted = true; }
            else if (event.key === Qt.Key_G) { Recorder.target = "region"; event.accepted = true; }
            else if (event.key === Qt.Key_A) { Recorder.audioDesktop = !Recorder.audioDesktop; event.accepted = true; }
            else if (event.key === Qt.Key_M) { Recorder.audioMic = !Recorder.audioMic; event.accepted = true; }
            else if (event.key === Qt.Key_C) { Recorder.showCursor = !Recorder.showCursor; event.accepted = true; }
            else if (event.key === Qt.Key_F) { Recorder.fps = (Recorder.fps === 60 ? 30 : 60); event.accepted = true; }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        // Основной блок управления записью (2 ряда для компактной ширины)
        Rectangle {
            width: parent.width
            height: recInnerCol.implicitHeight + Theme.px(24)
            radius: Theme.px(20)
            color: Theme.card

            Column {
                id: recInnerCol
                anchors.fill: parent
                anchors.margins: Theme.px(12)
                spacing: Theme.px(10)

                // Верхний ряд: выбор цели (Экран / Область) + кнопка Запись/Стоп
                Item {
                    width: parent.width
                    height: Theme.px(44)

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(8)

                        Repeater {
                            model: [
                                { key: "screen", label: "Весь экран [S]", icon: "desktop_windows" },
                                { key: "region", label: "Область [G]", icon: "crop_free" }
                            ]
                            Rectangle {
                                id: tgtBtn
                                required property var modelData
                                readonly property bool active: Recorder.target === modelData.key
                                width: Theme.px(138)
                                height: Theme.px(42)
                                radius: Theme.px(13)
                                color: active ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                                border.width: active ? 1.5 : 0
                                border.color: Theme.text

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.px(7)
                                    Icon { name: tgtBtn.modelData.icon; size: Theme.px(16); anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tgtBtn.modelData.label
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.px(12)
                                        font.weight: Font.DemiBold
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !Recorder.recording
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Recorder.target = tgtBtn.modelData.key
                                }
                            }
                        }
                    }

                    // Кнопка Старт / Стоп [Enter]
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(148)
                        height: Theme.px(42)
                        radius: height / 2
                        color: Recorder.recording ? Theme.text : Theme.red
                        scale: recMa.pressed ? 0.92 : 1.0
                        Behavior on scale { Spring {} }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.px(7)
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: Recorder.recording ? "stop" : "fiber_manual_record"
                                size: Theme.px(16)
                                color: Recorder.recording ? Theme.red : "white"
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Recorder.recording ? ("Стоп · " + Recorder.elapsedText) : "Запись [↵]"
                                color: Recorder.recording ? "black" : "white"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: Font.Bold
                            }
                        }

                        MouseArea {
                            id: recMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleRec()
                        }
                    }
                }

                // Нижний ряд: Опции (Система, Микрофон, Курсор, 60 FPS)
                Row {
                    width: parent.width
                    spacing: Theme.px(8)
                    readonly property real chipW: (width - 3 * spacing) / 4

                    Repeater {
                        model: [
                            { key: "audio", icon: "volume_up", label: "Система [A]", on: Recorder.audioDesktop },
                            { key: "mic", icon: "mic", label: "Микрофон [M]", on: Recorder.audioMic },
                            { key: "cursor", icon: "mouse", label: "Курсор [C]", on: Recorder.showCursor },
                            { key: "fps", icon: "speed", label: Recorder.fps + " FPS [F]", on: Recorder.fps === 60 }
                        ]
                        Rectangle {
                            id: optChip
                            required property var modelData
                            width: parent.chipW
                            height: Theme.px(34)
                            radius: Theme.px(11)
                            color: modelData.on ? Theme.blue : Qt.rgba(1, 1, 1, 0.08)

                            Row {
                                id: optRow
                                anchors.centerIn: parent
                                spacing: Theme.px(6)
                                Icon { name: optChip.modelData.icon; size: Theme.px(15); anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: optChip.modelData.label
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(11)
                                    font.weight: Font.DemiBold
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !Recorder.recording
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const k = optChip.modelData.key;
                                    if (k === "audio") Recorder.audioDesktop = !Recorder.audioDesktop;
                                    else if (k === "mic") Recorder.audioMic = !Recorder.audioMic;
                                    else if (k === "cursor") Recorder.showCursor = !Recorder.showCursor;
                                    else if (k === "fps") Recorder.fps = (Recorder.fps === 60 ? 30 : 60);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Последние записи
        Rectangle {
            visible: Recorder.recentFiles.length > 0
            width: parent.width
            height: Theme.px(44)
            radius: Theme.px(14)
            color: Theme.card

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(14)
                anchors.rightMargin: Theme.px(14)
                spacing: Theme.px(10)

                Icon { name: "folder_open"; size: Theme.px(18); color: Theme.text2; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Последняя запись: " + (Recorder.recentFiles[0] ? Recorder.recentFiles[0].split("/").pop() : "")
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(12)
                    elide: Text.ElideRight
                    width: parent.width - Theme.px(140)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Открыть →"
                    color: Theme.blue
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(12)
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
