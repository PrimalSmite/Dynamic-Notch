import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.services
import qs.components

// Панель микшера: основная громкость, микрофон и звуковые потоки приложений (←/→ громкость, M — звук, I — микрофон).
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    implicitHeight: col.implicitHeight

    Keys.onPressed: event => {
        if (event.key === Qt.Key_M) { Audio.toggleMute(); event.accepted = true; }
        else if (event.key === Qt.Key_I) { if (sourceReady) defaultSource.audio.muted = !defaultSource.audio.muted; event.accepted = true; }
        else if (event.key === Qt.Key_Left) { Audio.step(-0.05); event.accepted = true; }
        else if (event.key === Qt.Key_Right) { Audio.step(0.05); event.accepted = true; }
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

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        // Выходное устройство + большой слайдер
        VolumeCard {
            width: parent.width
        }

        // Микрофон
        Rectangle {
            visible: root.sourceReady
            width: parent.width
            height: Theme.px(54)
            radius: Theme.px(18)
            color: Theme.card

            Row {
                anchors.fill: parent
                anchors.margins: Theme.px(12)
                spacing: Theme.px(12)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(32); height: width; radius: width / 2
                    color: root.sourceMuted ? Theme.red : Qt.rgba(1, 1, 1, 0.12)
                    Icon {
                        anchors.centerIn: parent
                        name: root.sourceMuted ? "mic_off" : "mic"
                        size: Theme.px(18)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.sourceReady) root.defaultSource.audio.muted = !root.defaultSource.audio.muted
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(120)
                    elide: Text.ElideRight
                    text: "Микрофон"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(13)
                    font.weight: Font.DemiBold
                }

                Bar {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.px(230)
                    height: Theme.px(8)
                    value: root.sourceMuted ? 0 : root.sourceVol
                    tint: root.sourceMuted ? Theme.red : Theme.blue
                    interactive: true
                    onMoved: v => {
                        if (!root.sourceReady) return;
                        root.defaultSource.audio.muted = false;
                        root.defaultSource.audio.volume = v;
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(44)
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(root.sourceVol * 100) + "%"
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(12)
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                }
            }
        }

        // Приложения
        Rectangle {
            visible: root.streams.length > 0
            width: parent.width
            height: streamCol.implicitHeight + Theme.px(24)
            radius: Theme.px(20)
            color: Theme.card

            Column {
                id: streamCol
                anchors.fill: parent
                anchors.margins: Theme.px(12)
                spacing: Theme.px(10)

                Text {
                    text: "Приложения"
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                    font.weight: Font.Bold
                }

                Repeater {
                    model: root.streams
                    Item {
                        id: sRow
                        required property var modelData
                        width: streamCol.width
                        height: Theme.px(36)

                        readonly property real vol: modelData.audio ? modelData.audio.volume : 0
                        readonly property bool muted: modelData.audio ? modelData.audio.muted : false

                        Row {
                            anchors.fill: parent
                            spacing: Theme.px(10)

                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: Theme.px(24)
                                source: root.streamIcon(sRow.modelData)
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(180)
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: root.streamName(sRow.modelData)
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(12)
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: root.streamSub(sRow.modelData)
                                    color: Theme.text3
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(10)
                                }
                            }

                            Bar {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Theme.px(280)
                                height: Theme.px(7)
                                value: sRow.muted ? 0 : sRow.vol
                                tint: sRow.muted ? Theme.red : Theme.green
                                interactive: true
                                onMoved: v => {
                                    if (!sRow.modelData.audio) return;
                                    sRow.modelData.audio.muted = false;
                                    sRow.modelData.audio.volume = v;
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(42)
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(sRow.vol * 100) + "%"
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
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
