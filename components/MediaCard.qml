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

    Component.onCompleted: Media.activeConsumers++
    Component.onDestruction: Media.activeConsumers--

    // Колесо мыши по карточке меняет громкость
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => Audio.step(w.angleDelta.y > 0 ? 0.03 : -0.03)
    }

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
                Icon { anchors.centerIn: parent; name: "music_note"; size: Theme.px(30) }
            }
            Image {
                anchors.fill: parent
                source: Media.trackArtUrl !== "" ? Media.trackArtUrl : ((root.player && root.player.trackArtUrl) ? root.player.trackArtUrl : "")
                cache: false
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(136, 136)
                visible: status === Image.Ready && source !== ""
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
                text: Media.trackTitle !== "" ? Media.trackTitle : ((root.player && root.player.trackTitle) ? root.player.trackTitle : "Без названия")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(15)
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Media.trackArtist !== "" ? Media.trackArtist : (root.player ? (root.player.trackArtist || root.player.identity) : "")
                color: Theme.text2
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(12)
            }
            Item { width: 1; height: Theme.px(6) }
            Bar {
                id: prog
                width: parent.width
                height: Theme.px(4)
                tint: Theme.controlFill
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

        // Кнопки управления (Назад, Плей/Пауза, Вперед)
        Row {
            id: ctl
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(4)

            // Предыдущий трек
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(30); height: width; radius: width / 2
                color: prevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                scale: prevMa.pressed ? 0.88 : 1.0
                Behavior on scale { Spring { epsilon: 0.01 } }

                Icon {
                    anchors.centerIn: parent
                    name: "skip_previous"
                    size: Theme.px(20)
                    color: Theme.text
                }
                MouseArea {
                    id: prevMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.prev()
                }
            }

            // Плей / Пауза (акцентная матово-белая круглая кнопка)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(36); height: width; radius: width / 2
                color: Theme.controlFill
                scale: playMa.pressed ? 0.88 : (playMa.containsMouse ? 1.05 : 1.0)
                Behavior on scale { Spring { epsilon: 0.01 } }

                Icon {
                    anchors.centerIn: parent
                    name: Media.playing ? "pause" : "play_arrow"
                    size: Theme.px(22)
                    color: "black"
                }
                MouseArea {
                    id: playMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.togglePlay()
                }
            }

            // Следующий трек
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(30); height: width; radius: width / 2
                color: nextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                scale: nextMa.pressed ? 0.88 : 1.0
                Behavior on scale { Spring { epsilon: 0.01 } }

                Icon {
                    anchors.centerIn: parent
                    name: "skip_next"
                    size: Theme.px(20)
                    color: Theme.text
                }
                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.next()
                }
            }
        }
    }
}
