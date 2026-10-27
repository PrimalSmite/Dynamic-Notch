import QtQuick
import Quickshell.Widgets
import qs.services

// Карточка плеера: обложка, трек, прогресс и кнопки.
Rectangle {
    id: root
    readonly property var player: Media.player

    implicitHeight: 96
    radius: 22
    color: Theme.card

    Row {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        // Обложка
        ClippingRectangle {
            width: 68
            height: 68
            radius: 16
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
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(136, 136)
                visible: status === Image.Ready
            }
        }

        // Трек + прогресс
        Column {
            width: parent.width - 68 - ctl.width - 2 * parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.player?.trackTitle || "Без названия"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.player ? (root.player.trackArtist || root.player.identity) : ""
                color: Theme.text2
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
            Item { width: 1; height: 6 }
            Bar {
                id: prog
                width: parent.width
                height: 4
                visible: root.player?.lengthSupported ?? false
                value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
                interactive: root.player?.canSeek ?? false
                onMoved: v => { if (root.player) root.player.position = v * root.player.length; }
            }
            Item {
                width: parent.width
                height: 14
                visible: prog.visible
                Text {
                    text: Media.fmt(root.player?.position ?? 0)
                    color: Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.features: { "tnum": 1 }
                }
                Text {
                    anchors.right: parent.right
                    text: "-" + Media.fmt((root.player?.length ?? 0) - (root.player?.position ?? 0))
                    color: Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.features: { "tnum": 1 }
                }
            }
        }

        // Кнопки
        Row {
            id: ctl
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: [
                    { icon: "skip_previous", act: "prev", size: 26 },
                    { icon: Media.playing ? "pause" : "play_arrow", act: "toggle", size: 34 },
                    { icon: "skip_next", act: "next", size: 26 }
                ]
                Item {
                    id: btn
                    required property var modelData
                    width: 36
                    height: 40
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
