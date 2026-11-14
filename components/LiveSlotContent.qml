import QtQuick
import Quickshell.Widgets
import qs.services

// Shared renderer for a Live Activity widget in one of three layouts:
//   "left"    — left half when a single widget spans both sides of the notch
//   "right"   — right half when a single widget spans both sides of the notch
//   "compact" — unified compact form when 2+ widgets share the notch/duo space
Row {
    id: root

    property string kind: ""
    property string part: "compact"      // "left" | "right" | "compact"
    property bool notchHovered: false
    property real mediaProgress: 0
    property int overflowCount: 0

    spacing: Theme.px(5)

    // ── 1. Media ──
    Row {
        visible: root.kind === "media"
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(5)

        ClippingRectangle {
            visible: root.part === "left" || root.part === "compact"
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(20)
            height: Theme.px(20)
            radius: Theme.px(6)
            color: Qt.rgba(1, 1, 1, 0.09)

            Icon {
                anchors.centerIn: parent
                name: "music_note"
                size: Theme.px(12)
                color: Theme.text2
                visible: !artImg.visible
            }
            Image {
                id: artImg
                anchors.fill: parent
                source: Media.trackArtUrl
                cache: true
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(48, 48)
                visible: status === Image.Ready && source !== ""
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.px(2)
                color: Qt.rgba(0, 0, 0, 0.45)
                visible: root.mediaProgress > 0

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * root.mediaProgress
                    color: Theme.text
                }
            }
        }

        AudioWave {
            visible: root.part === "right"
            anchors.verticalCenter: parent.verticalCenter
            active: Media.playing
            color: Media.playing ? Theme.text : Theme.text3
            maxH: Theme.px(12)
            minH: Theme.px(3)
        }

        Text {
            visible: root.part === "right" && IslandPrefs.liveMediaShowTitle && Media.trackTitle !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Theme.px(74))
            elide: Text.ElideRight
            text: Media.trackTitle
            color: Theme.text2
            font.family: Theme.fontFamily
            font.pixelSize: Theme.px(11)
            font.weight: Font.Medium
        }
    }

    // ── 2. Mic Privacy / Mute ──
    Row {
        visible: root.kind === "mic"
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(4)

        Rectangle {
            visible: (root.part === "left" || root.part === "compact") && !Audio.micMuted && Audio.micInUse
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(5)
            height: width
            radius: width / 2
            color: Theme.orange

            SequentialAnimation on opacity {
                running: root.kind === "mic" && !Audio.micMuted && Audio.micInUse && root.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 750; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutSine }
            }
        }

        Icon {
            visible: root.part === "left" || root.part === "compact"
            anchors.verticalCenter: parent.verticalCenter
            name: Audio.micMuted ? "mic_off" : "mic"
            size: Theme.px(13)
            color: Audio.micMuted ? Theme.red : Theme.orange
        }

        Text {
            visible: root.part === "right"
            anchors.verticalCenter: parent.verticalCenter
            text: Audio.micMuted ? "MUTED" : "MIC"
            color: Audio.micMuted ? Theme.red : Theme.orange
            font.family: Theme.fontFamily
            font.pixelSize: Theme.px(10)
            font.weight: Font.Bold
            font.letterSpacing: Theme.px(0.4)
        }
    }

    // ── 3. Thermal / Load Alert ──
    Row {
        visible: root.kind === "thermal"
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(3)

        readonly property bool tempHot: SysInfo.cpuTemp >= 80
        readonly property bool cpuHot: SysInfo.highLoadAlert
        readonly property color tintColor: (SysInfo.cpuTemp >= 90 || SysInfo.mem >= 0.94) ? Theme.red : Theme.warn
        readonly property string valText: tempHot ? (SysInfo.cpuTemp + "°")
                                        : cpuHot ? (Math.round(SysInfo.cpu * 100) + "%")
                                        : (Math.round(SysInfo.mem * 100) + "%")

        Icon {
            visible: root.part === "left" || root.part === "compact"
            anchors.verticalCenter: parent.verticalCenter
            name: parent.tempHot ? "local_fire_department" : "memory"
            size: Theme.px(13)
            color: parent.tintColor
        }
        Text {
            visible: root.part === "right" || root.part === "compact"
            anchors.verticalCenter: parent.verticalCenter
            text: parent.valText
            color: root.part === "right" ? parent.tintColor : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.px(11)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    // ── 4. External IPC Task ──
    Row {
        visible: root.kind === "ipc" && LiveActivity.ipcTask !== null
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(5)

        ProgressRing {
            visible: (root.part === "left" || root.part === "compact") && (LiveActivity.ipcTask ? !LiveActivity.ipcTask.done : false)
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.px(14)
            strokeWidth: Theme.px(1.8)
            indeterminate: LiveActivity.ipcTask ? (LiveActivity.ipcTask.progress < 0) : true
            value: LiveActivity.ipcTask ? Math.max(0, LiveActivity.ipcTask.progress) : 0
            fillColor: Theme.text
        }

        Icon {
            visible: (root.part === "left" || root.part === "compact") && (LiveActivity.ipcTask ? !!LiveActivity.ipcTask.done : false)
            anchors.verticalCenter: parent.verticalCenter
            name: (LiveActivity.ipcTask && LiveActivity.ipcTask.ok) ? "check_circle" : "error"
            size: Theme.px(14)
            color: (LiveActivity.ipcTask && LiveActivity.ipcTask.ok) ? Theme.green : Theme.red
        }

        Text {
            visible: root.part === "right" || root.part === "compact"
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Theme.px(64))
            elide: Text.ElideRight
            text: LiveActivity.ipcTask ? LiveActivity.ipcTask.label : ""
            color: Theme.text2
            font.family: Theme.fontFamily
            font.pixelSize: Theme.px(11)
            font.weight: Font.DemiBold
        }
    }

    // ── 5. Active System Modes ──
    Row {
        visible: root.kind === "modes"
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(4)

        readonly property string modeIcon: SysToggles.keepAwake ? "coffee"
                                         : SysToggles.nightLight ? "bedtime"
                                         : "sports_esports"
        readonly property string modeLabel: SysToggles.keepAwake ? "AWAKE"
                                          : SysToggles.nightLight ? "NIGHT"
                                          : "GAME"
        readonly property color modeColor: SysToggles.keepAwake ? Theme.yellow
                                         : SysToggles.nightLight ? Theme.orange
                                         : Theme.teal

        Icon {
            visible: root.part === "left" || root.part === "compact"
            anchors.verticalCenter: parent.verticalCenter
            name: parent.modeIcon
            size: Theme.px(13)
            color: parent.modeColor
        }
        Text {
            visible: root.part === "right"
            anchors.verticalCenter: parent.verticalCenter
            text: parent.modeLabel
            color: parent.modeColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.px(10)
            font.weight: Font.Bold
            font.letterSpacing: Theme.px(0.4)
        }
    }

    // ── 6. Audio Output Muted ──
    Row {
        visible: root.kind === "muted"
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(4)

        Icon {
            visible: root.part === "left" || root.part === "compact"
            anchors.verticalCenter: parent.verticalCenter
            name: "volume_off"
            size: Theme.px(13)
            color: Theme.red
        }
        Text {
            visible: root.part === "right"
            anchors.verticalCenter: parent.verticalCenter
            text: "MUTED"
            color: Theme.red
            font.family: Theme.fontFamily
            font.pixelSize: Theme.px(10)
            font.weight: Font.Bold
            font.letterSpacing: Theme.px(0.4)
        }
    }

    // ── 7. Screen Recorder ──
    Row {
        visible: root.kind === "recorder"
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(5)

        Item {
            visible: root.part === "left" || root.part === "compact"
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(11)
            height: Theme.px(14)

            Rectangle {
                id: recHalo
                anchors.centerIn: parent
                width: Theme.px(10)
                height: width
                radius: width / 2
                color: Theme.red
                opacity: Recorder.recording ? 0.28 : 0
            }

            Rectangle {
                anchors.centerIn: parent
                width: Theme.px(6)
                height: width
                radius: width / 2
                color: Theme.red
            }
        }

        RollingClock {
            visible: root.part === "right" || root.part === "compact"
            anchors.verticalCenter: parent.verticalCenter
            timeString: Recorder.elapsedText
            fontSize: Theme.px(12)
            fontWeight: Font.DemiBold
            textColor: Theme.red
        }
    }

    // ── 9. Timer / Stopwatch (crisp vector ring + hand matching iOS Dynamic Island) ──
    Row {
        visible: root.kind === "timer"
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(5)

        Item {
            id: liveTimerIcon
            visible: root.part === "left" || root.part === "compact"
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(17)
            height: Theme.px(17)

            ProgressRing {
                anchors.centerIn: parent
                size: Theme.px(15)
                strokeWidth: Theme.px(1.8)
                value: Timers.progress
                fillColor: Theme.orange
                trackColor: Qt.rgba(1, 0.62, 0.04, 0.24)
            }

            // Crisp vector clock hand & pivot
            Item {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                rotation: Timers.mode === "stopwatch" ? ((Timers.elapsedSec % 60) * 6) : -40
                Behavior on rotation { Spring { epsilon: 0.5 } }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height / 2 - height
                    width: Theme.px(1.8)
                    height: Theme.px(4.2)
                    radius: width / 2
                    color: Theme.orange
                    antialiasing: true
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: Theme.px(2.8)
                height: width
                radius: width / 2
                color: Theme.orange
                antialiasing: true
            }
        }

        RollingClock {
            visible: root.part === "right"
            anchors.verticalCenter: parent.verticalCenter
            timeString: Timers.compactDisplay
            fontSize: Theme.px(12)
            fontWeight: Font.DemiBold
            textColor: Theme.orange
        }
    }

    // Subtle overflow counter (+N)
    Text {
        visible: root.overflowCount > 0
        anchors.verticalCenter: parent.verticalCenter
        text: "+" + root.overflowCount
        color: Theme.text3
        font.family: Theme.fontFamily
        font.pixelSize: Theme.px(10)
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }
}
