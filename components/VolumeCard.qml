import QtQuick
import Quickshell.Services.Pipewire
import qs.services

// Компактная карточка громкости в стиле Dynamic Notch / iOS:
// кнопка mute, имя выхода, аккуратный слайдер и горизонтальные пилюли выходов.
Rectangle {
    id: root

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    function cleanSinkName(n) {
        if (!n) return "";
        let s = n.description || n.nickname || n.name || "";
        s = s.replace(/Analog Stereo/gi, "Динамики")
             .replace(/Digital Stereo \(HDMI.*?\)/gi, "HDMI")
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

    implicitHeight: col.implicitHeight + 2 * Theme.px(12)
    radius: Theme.px(18)
    color: Theme.card

    PwObjectTracker { objects: root.sinks }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => Audio.step(w.angleDelta.y > 0 ? 0.03 : -0.03)
    }

    Column {
        id: col
        width: parent.width - 2 * Theme.px(12)
        x: Theme.px(12)
        y: Theme.px(12)
        spacing: Theme.px(10)

        // Шапка: Mute, имя выхода и процент
        Item {
            width: parent.width
            height: Theme.px(34)

            Rectangle {
                id: muteBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(32)
                height: Theme.px(32)
                radius: Theme.px(10)
                color: Audio.muted ? Theme.red : Qt.rgba(1, 1, 1, 0.10)
                scale: muteMa.pressed ? 0.90 : (muteMa.containsMouse ? 1.04 : 1.0)
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on scale { Spring { epsilon: 0.002 } }

                Icon {
                    anchors.centerIn: parent
                    name: Audio.icon
                    size: Theme.px(17)
                    color: Audio.muted ? "white" : Theme.text
                }
                MouseArea {
                    id: muteMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Audio.toggleMute()
                }
            }

            Column {
                anchors.left: muteBtn.right
                anchors.leftMargin: Theme.px(10)
                anchors.right: pct.left
                anchors.rightMargin: Theme.px(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(1)

                Text {
                    text: "Громкость"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(13)
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Audio.muted ? "Звук отключён [M]" : root.cleanSinkName(Audio.sink)
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                }
            }

            Text {
                id: pct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(Audio.volume * 100) + "%"
                color: Audio.muted ? Theme.red : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(17)
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
        }

        // Интерактивный слайдер
        Bar {
            width: parent.width
            height: Theme.px(12)
            value: Audio.muted ? 0 : Audio.volume
            tint: Audio.muted ? Theme.red : Theme.text
            interactive: true
            onMoved: v => Audio.setVolume(v)
        }

        // Выходы звука (если их больше одного — горизонтальный скроллируемый ряд пилюль)
        Flickable {
            id: sinkScroll
            width: parent.width
            height: Theme.px(24)
            visible: root.sinks.length > 1
            clip: true
            contentWidth: sinkRow.implicitWidth
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: sinkRow
                spacing: Theme.px(6)

                Repeater {
                    model: root.sinks
                    Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool current: modelData === Audio.sink
                        height: Theme.px(24)
                        width: chipRow.implicitWidth + Theme.px(16)
                        radius: height / 2
                        color: current ? Theme.text : Qt.rgba(1, 1, 1, 0.08)
                        scale: chipMa.pressed ? 0.92 : 1.0
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on scale { Spring { epsilon: 0.002 } }

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: Theme.px(5)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: root.sinkIcon(chip.modelData)
                                size: Theme.px(13)
                                color: chip.current ? "black" : Theme.text2
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.cleanSinkName(chip.modelData)
                                color: chip.current ? "black" : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Pipewire.preferredDefaultAudioSink = chip.modelData
                        }
                    }
                }
            }
        }
    }
}
