import QtQuick
import Quickshell.Widgets
import qs.services

// Карточка плеера: обложка, трек, прогресс и кнопки.
Rectangle {
    id: root
    readonly property var player: Media.player

    implicitHeight: Theme.px(96)
    radius: Theme.px(22)
    color: Theme.card

    Row {
        anchors.fill: parent
        anchors.margins: Theme.px(14)
        spacing: Theme.px(14)
        // Обложка
        ClippingRectangle {
            width: Theme.px(68)
            height: Theme.px(68)
            radius: Theme.px(16)
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.pink }
                    GradientStop { position: 1; color: Theme.purple }
                }
                Icon { anchors.centerIn: parent; name: "music_note"; size: 30 }
            }
            Image {
                anchors.fill: parent
                source: (root.player && root.player.trackArtUrl) ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(136, 136)
                visible: status === Image.Ready
            }
        }

        // Трек + прогресс
        Column {
            width: parent.width - Theme.px(68) - ctl.width - 2 * parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(3)
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: (root.player && root.player.trackTitle) ? root.player.trackTitle : "Без названия"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(15)
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.player ? (root.player.trackArtist || root.player.identity) : ""
                color: Theme.text2
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(12)
            }
            Item { width: 1; height: 6 }
            Bar {
                id: prog
                width: parent.width
                height: Theme.px(4)
                visible: root.player ? root.player.lengthSupported : false
                value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
                interactive: root.player ? root.player.canSeek : false
                onMoved: v => { if (root.player) root.player.position = v * root.player.length; }
            }
            Item {
                width: parent.width
                height: Theme.px(14)
                visible: prog.visible
                Text {
                    text: Media.fmt((root.player && root.player.position) ? root.player.position : 0)
                    color: Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(10)
                    font.features: { "tnum": 1 }
                }
                Text {
                    anchors.right: parent.right
                    text: "-" + Media.fmt(((root.player && root.player.length) ? root.player.length : 0) - ((root.player && root.player.position) ? root.player.position : 0))
                    color: Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(10)
                    font.features: { "tnum": 1 }
                }
            }
        }

        // Кнопки
        Row {
            id: ctl
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(2)
            Repeater {
                model: [
                    { icon: "skip_previous", act: "prev", size: Theme.px(26) },
                    { icon: Media.playing ? "pause" : "play_arrow", act: "toggle", size: Theme.px(34) },
                    { icon: "skip_next", act: "next", size: Theme.px(26) }
                ]
                Item {
                    id: btn
                    required property var modelData
                    width: Theme.px(36)
                    height: Theme.px(40)
                    Icon {
                        anchors.centerIn: parent
                        name: btn.modelData.icon
                        size: btn.modelData.size
                        scale: bm.pressed ? 0.8 : bm.containsMouse ? 1.1 : 1
                        Behavior on scale { NumberAnimation { duration: 140 } }
                    }
                    MouseArea {
                        id: bm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const p = root.player;
                            if (!p) return;
                            if (btn.modelData.act === "prev") p.previous();
                            else if (btn.modelData.act === "next") p.next();
                            else p.togglePlaying();
                        }
                    }
                }
            }
        }
    }
}
