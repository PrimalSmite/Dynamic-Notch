import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.services
import qs.components

// Панель микшера: компактная карточка звука в стиле Dynamic Notch.
// Горячие клавиши: ←/→ (или ↑/↓) — громкость, M — звук, I — микрофон. Колесо мыши — громкость.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true

    implicitWidth: Theme.px(390)
    implicitHeight: col.implicitHeight

    Keys.onPressed: event => {
        const t = (event.text || "").toLowerCase();
        if (event.key === Qt.Key_M || t === "m" || t === "ь") {
            Audio.toggleMute();
            event.accepted = true;
        } else if (event.key === Qt.Key_I || t === "i" || t === "ш") {
            if (sourceReady) defaultSource.audio.muted = !defaultSource.audio.muted;
            event.accepted = true;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) {
            Audio.step(-0.04);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) {
            Audio.step(0.04);
            event.accepted = true;
        }
    }

    readonly property PwNode defaultSource: Pipewire.defaultAudioSource
    readonly property bool sourceReady: defaultSource !== null && defaultSource.ready && defaultSource.audio !== null
    readonly property real sourceVol: sourceReady ? defaultSource.audio.volume : 0
    readonly property bool sourceMuted: sourceReady ? defaultSource.audio.muted : false

    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)

    PwObjectTracker {
        objects: (root.defaultSource ? [root.defaultSource] : []).concat(root.streams)
    }

    function streamName(n) {
        if (!n) return "Приложение";
        const p = n.properties || {};
        return p["application.name"] || n.description || n.nickname || n.name || "Поток";
    }

    function streamSub(n) {
        if (!n) return "";
        const p = n.properties || {};
        return p["media.name"] || n.description || "";
    }

    function streamIcon(n) {
        if (!n) return "";
        const p = n.properties || {};
        const ic = p["application.icon-name"] || p["application.process.binary"] || n.name || "";
        return Quickshell.iconPath(ic, "audio-x-generic");
    }

    // Колесо мыши по любой свободной области меняет мастер-громкость
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => Audio.step(w.angleDelta.y > 0 ? 0.03 : -0.03)
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(8)

        // 1. Основной выход звука + селектор устройств
        VolumeCard {
            width: parent.width
        }

        // 2. Микрофон (компактная плашка)
        Rectangle {
            visible: root.sourceReady
            width: parent.width
            height: Theme.px(42)
            radius: Theme.px(14)
            color: Theme.card

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: w => {
                    if (!root.sourceReady) return;
                    root.defaultSource.audio.muted = false;
                    root.defaultSource.audio.volume = Math.max(0, Math.min(1, root.sourceVol + (w.angleDelta.y > 0 ? 0.04 : -0.04)));
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: Theme.px(8)
                spacing: Theme.px(9)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(26)
                    height: Theme.px(26)
                    radius: Theme.px(8)
                    color: root.sourceMuted ? Theme.alert : Qt.rgba(1, 1, 1, 0.10)
                    scale: micMa.pressed ? 0.88 : (micMa.containsMouse ? 1.05 : 1.0)
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on scale { Spring { epsilon: 0.002 } }

                    Icon {
                        anchors.centerIn: parent
                        name: root.sourceMuted ? "mic_off" : "mic"
                        size: Theme.px(15)
                        color: root.sourceMuted ? "white" : Theme.controlFill
                    }
                    MouseArea {
                        id: micMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.sourceReady) root.defaultSource.audio.muted = !root.defaultSource.audio.muted
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(68)
                    elide: Text.ElideRight
                    text: "Микрофон"
                    color: root.sourceMuted ? Theme.alert : Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                    font.weight: Font.DemiBold
                }

                Bar {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.px(155)
                    height: Theme.px(6)
                    value: root.sourceMuted ? 0 : root.sourceVol
                    tint: root.sourceMuted ? Theme.alert : Theme.controlFill
                    interactive: true
                    onMoved: v => {
                        if (!root.sourceReady) return;
                        root.defaultSource.audio.muted = false;
                        root.defaultSource.audio.volume = v;
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(36)
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(root.sourceVol * 100) + "%"
                    color: root.sourceMuted ? Theme.alert : Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
        }

        // 3. Звуковые потоки приложений (аккуратный ограниченный список со скроллом)
        Rectangle {
            visible: root.streams.length > 0
            width: parent.width
            height: streamHeader.implicitHeight + streamScroll.height + Theme.px(20)
            radius: Theme.px(16)
            color: Theme.card

            Column {
                anchors.fill: parent
                anchors.margins: Theme.px(10)
                spacing: Theme.px(8)

                // Заголовок секции приложений
                Item {
                    id: streamHeader
                    width: parent.width
                    height: Theme.px(16)

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(6)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "tune"
                            size: Theme.px(13)
                            color: Theme.text3
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Приложения"
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.streams.length.toString()
                        color: Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(10)
                        font.weight: Font.Medium
                    }
                }

                // Скроллируемый контейнер потоков (не раздувает чёлку)
                Flickable {
                    id: streamScroll
                    width: parent.width
                    height: Math.min(Theme.px(105), streamCol.implicitHeight)
                    contentHeight: streamCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: streamCol
                        width: parent.width
                        spacing: Theme.px(6)

                        Repeater {
                            model: root.streams
                            Item {
                                id: sRow
                                required property var modelData
                                width: streamCol.width
                                height: Theme.px(28)

                                readonly property real vol: modelData.audio ? modelData.audio.volume : 0
                                readonly property bool muted: modelData.audio ? modelData.audio.muted : false

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    onWheel: w => {
                                        if (!sRow.modelData.audio) return;
                                        sRow.modelData.audio.muted = false;
                                        sRow.modelData.audio.volume = Math.max(0, Math.min(1, sRow.vol + (w.angleDelta.y > 0 ? 0.04 : -0.04)));
                                    }
                                }

                                Row {
                                    anchors.fill: parent
                                    spacing: Theme.px(8)

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Theme.px(22)
                                        height: Theme.px(22)
                                        radius: Theme.px(6)
                                        color: sRow.muted ? Theme.alert : Qt.rgba(1, 1, 1, 0.08)
                                        scale: sIconMa.pressed ? 0.90 : 1.0
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                        Behavior on scale { Spring { epsilon: 0.002 } }

                                        IconImage {
                                            anchors.centerIn: parent
                                            implicitSize: Theme.px(14)
                                            source: root.streamIcon(sRow.modelData)
                                            visible: !sRow.muted
                                        }

                                        Icon {
                                            anchors.centerIn: parent
                                            name: "volume_off"
                                            size: Theme.px(12)
                                            color: "white"
                                            visible: sRow.muted
                                        }

                                        MouseArea {
                                            id: sIconMa
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (sRow.modelData.audio) {
                                                    sRow.modelData.audio.muted = !sRow.muted;
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Theme.px(85)
                                        elide: Text.ElideRight
                                        text: root.streamName(sRow.modelData)
                                        color: sRow.muted ? Theme.text3 : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.px(11)
                                        font.weight: Font.Medium
                                    }

                                    Bar {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - Theme.px(165)
                                        height: Theme.px(5)
                                        value: sRow.muted ? 0 : sRow.vol
                                        tint: sRow.muted ? Theme.alert : Theme.controlFill
                                        interactive: true
                                        onMoved: v => {
                                            if (!sRow.modelData.audio) return;
                                            sRow.modelData.audio.muted = false;
                                            sRow.modelData.audio.volume = v;
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Theme.px(34)
                                        horizontalAlignment: Text.AlignRight
                                        text: Math.round(sRow.vol * 100) + "%"
                                        color: sRow.muted ? Theme.text3 : Theme.text2
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.px(10)
                                        font.weight: Font.DemiBold
                                        font.features: { "tnum": 1 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
