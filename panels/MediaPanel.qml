import QtQuick
import qs.services
import qs.components

// Панель «Сейчас играет».
// Горячие клавиши: Space — плей/пауза, ← — назад, → — вперед, ↑/↓ — громкость, M — звук.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true

    implicitWidth: Theme.px(390)
    implicitHeight: col.implicitHeight

    Keys.onPressed: event => {
        const t = (event.text || "").toLowerCase();
        if (event.key === Qt.Key_Space) {
            Media.togglePlay();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            Media.prev();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            Media.next();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            Audio.step(0.04);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            Audio.step(-0.04);
            event.accepted = true;
        } else if (event.key === Qt.Key_M || t === "m" || t === "ь") {
            Audio.toggleMute();
            event.accepted = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => Audio.step(w.angleDelta.y > 0 ? 0.03 : -0.03)
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        // Карточка плеера
        MediaCard {
            width: parent.width
            visible: Media.player !== null
        }

        // Пустое состояние
        Rectangle {
            visible: Media.player === null
            width: parent.width
            height: Theme.px(110)
            radius: Theme.px(20)
            color: Theme.card

            Column {
                anchors.centerIn: parent
                spacing: Theme.px(6)
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "music_off"
                    size: Theme.px(30)
                    color: Theme.text3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Нет активного плеера"
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(13)
                }
            }
        }

        // Выбор плеера, если их несколько
        Row {
            visible: Media.players.length > 1
            spacing: Theme.px(6)
            Repeater {
                model: Media.players
                Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool current: modelData === Media.player
                    height: Theme.px(26)
                    width: chipText.implicitWidth + Theme.px(22)
                    radius: height / 2
                    color: current ? Theme.text : Theme.card
                    scale: chipMa.pressed ? 0.92 : 1.0
                    Behavior on scale { Spring { epsilon: 0.01 } }

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chip.modelData ? chip.modelData.identity : ""
                        color: chip.current ? "black" : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsSmall
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.pinned = chip.modelData
                    }
                }
            }
        }
    }
}
