import QtQuick
import Quickshell.Services.Pipewire
import qs.services

// Большая карточка громкости для дашборда:
// кнопка mute, имя устройства, толстый слайдер, переключение выходов.
Rectangle {
    id: root

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    function nodeName(n) { return n ? (n.description || n.nickname || n.name) : ""; }

    implicitHeight: col.implicitHeight + 28
    radius: 22
    color: Theme.card

    PwObjectTracker { objects: root.sinks }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => Audio.step(w.angleDelta.y > 0 ? 0.05 : -0.05)
    }

    Column {
        id: col
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Шапка
        Item {
            width: parent.width
            height: 36

            Rectangle {
                id: muteBtn
                width: 36
                height: 36
                radius: 18
                color: Audio.muted ? Theme.red : Qt.rgba(1, 1, 1, 0.12)
                scale: muteMa.pressed ? 0.88 : 1
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on scale { Spring {} }
                Icon {
                    anchors.centerIn: parent
                    name: Audio.icon
                    size: 20
                }
                MouseArea {
                    id: muteMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Audio.toggleMute()
                }
            }

            Column {
                anchors.left: muteBtn.right
                anchors.leftMargin: 12
                anchors.right: pct.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    text: "Громкость"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Audio.muted ? "Звук выключен" : root.nodeName(Audio.sink)
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            Text {
                id: pct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(Audio.volume * 100) + "%"
                color: Audio.muted ? Theme.text3 : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
        }

        // Толстый слайдер
        Bar {
            width: parent.width
            height: 26
            value: Audio.muted ? 0 : Audio.volume
            tint: Theme.text
            interactive: true
            onMoved: v => Audio.setVolume(v)
        }

        // Выходы (если их больше одного)
        Flow {
            width: parent.width
            spacing: 6
            visible: root.sinks.length > 1

            Repeater {
                model: root.sinks
                Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool current: modelData === Audio.sink
                    height: 26
                    width: Math.min(chipText.implicitWidth + 22, col.width)
                    radius: 13
                    color: current ? Theme.text : Qt.rgba(1, 1, 1, 0.1)
                    Behavior on color { ColorAnimation { duration: 180 } }
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, col.width - 22)
                        elide: Text.ElideRight
                        text: root.nodeName(chip.modelData)
                        color: chip.current ? "black" : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Pipewire.preferredDefaultAudioSink = chip.modelData
                    }
                }
            }
        }
    }
}
