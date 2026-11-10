import QtQuick
import Quickshell.Widgets
import qs.services

// Media player card: album art, track details, progress and controls.
Rectangle {
    id: root
    readonly property var player: Media.player

    implicitWidth: Theme.px(390)
    implicitHeight: Theme.px(112)
    radius: Theme.px(20)
    color: Theme.card

    Component.onCompleted: Media.activeConsumers++
    Component.onDestruction: Media.activeConsumers--

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => Audio.step(w.angleDelta.y > 0 ? 0.03 : -0.03)
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.px(14)
        spacing: Theme.px(14)

        // Album Art
        ClippingRectangle {
            width: Theme.px(84)
            height: Theme.px(84)
            radius: Theme.px(16)
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(1, 1, 1, 0.06)

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(1, 1, 1, 0.05)
                Icon {
                    anchors.centerIn: parent
                    name: "music_note"
                    size: Theme.px(28)
                    color: Theme.text3
                }
            }

            Image {
                anchors.fill: parent
                source: Media.trackArtUrl !== "" ? Media.trackArtUrl : ((root.player && root.player.trackArtUrl) ? root.player.trackArtUrl : "")
                cache: true
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(168, 168)
                visible: status === Image.Ready && source !== ""
            }
        }

        // Details, progress bar and playback controls
        Column {
            width: parent.width - Theme.px(84) - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(4)

            // Track title & artist
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Media.trackTitle !== "" ? Media.trackTitle : ((root.player && root.player.trackTitle) ? root.player.trackTitle : "No media playing")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(14)
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Media.trackArtist !== "" ? Media.trackArtist : (root.player ? (root.player.trackArtist || root.player.identity) : "")
                color: Theme.text2
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(11)
            }

            // Progress bar
            Item {
                width: parent.width
                height: Theme.px(16)

                Bar {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Theme.px(4)
                    tint: Theme.controlFill
                    value: root.player && root.player.length > 0 ? (root.player.position / root.player.length) : 0
                    interactive: root.player ? root.player.canSeek : false
                    onMoved: v => { if (root.player) root.player.position = v * root.player.length; }
                }
            }

            // Timestamps and playback controls container
            Item {
                width: parent.width
                height: Theme.px(28)

                // Current timestamp
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.fmt((root.player && root.player.position) ? root.player.position : 0)
                    color: Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(10)
                    font.features: { "tnum": 1 }
                }

                // Controls centered in column
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(8)

                    // Prev track
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(26); height: width; radius: width / 2
                        color: prevMa.containsMouse ? Theme.cardHover : "transparent"
                        scale: prevMa.pressed ? 0.88 : 1.0
                        Behavior on scale { Spring { epsilon: 0.01 } }

                        Icon {
                            anchors.centerIn: parent
                            name: "skip_previous"
                            size: Theme.px(17)
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

                    // Play/Pause (Clean circular button)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(32); height: width; radius: width / 2
                        color: Theme.controlFill
                        scale: playMa.pressed ? 0.88 : (playMa.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { Spring { epsilon: 0.01 } }

                        Icon {
                            anchors.centerIn: parent
                            name: Media.playing ? "pause" : "play_arrow"
                            size: Theme.px(19)
                            color: "#000000"
                        }
                        MouseArea {
                            id: playMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Media.togglePlay()
                        }
                    }

                    // Next track
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(26); height: width; radius: width / 2
                        color: nextMa.containsMouse ? Theme.cardHover : "transparent"
                        scale: nextMa.pressed ? 0.88 : 1.0
                        Behavior on scale { Spring { epsilon: 0.01 } }

                        Icon {
                            anchors.centerIn: parent
                            name: "skip_next"
                            size: Theme.px(17)
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

                // Total duration timestamp
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.fmt((root.player && root.player.length) ? root.player.length : 0)
                    color: Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(10)
                    font.features: { "tnum": 1 }
                }
            }
        }
    }
}
