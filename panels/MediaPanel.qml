import QtQuick
import qs.services
import qs.components

// Панель «Сейчас играет».
Item {
    id: root
    property var host: null
    implicitWidth: Theme.px(390)
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        MediaCard {
            width: parent.width
            visible: Media.player !== null
        }

        // выбор плеера, если их несколько
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
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chip.modelData.identity
                        color: chip.current ? "black" : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsSmall
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.pinned = chip.modelData
                    }
                }
            }
        }
    }
}
