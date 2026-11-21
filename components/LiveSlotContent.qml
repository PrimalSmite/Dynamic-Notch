import QtQuick
import Quickshell.Widgets
import qs.services

// Shared renderer for a Live Activity widget in one of three layouts:
//   "left"    — left half when a single widget spans both sides of the notch
//   "right"   — right half when a single widget spans both sides of the notch
//   "compact" — unified compact form when 2+ widgets share the notch/duo space
// Uses a lazy Loader so inactive activity kinds consume zero bindings, images, or timers.
Row {
    id: root

    property string kind: ""
    property string part: "compact"      // "left" | "right" | "compact"
    property real mediaProgress: 0
    property int overflowCount: 0

    spacing: Theme.px(5)

    Loader {
        id: slotLoader
        anchors.verticalCenter: parent.verticalCenter
        active: root.kind !== ""
        sourceComponent: {
            switch (root.kind) {
            case "media": return mediaComp;
            case "mic": return micComp;
            case "thermal": return thermalComp;
            case "ipc": return LiveActivity.ipcTask !== null ? ipcComp : null;
            case "modes": return modesComp;
            case "muted": return mutedComp;
            case "recorder": return recorderComp;
            case "timer": return timerComp;
            case "submap": return submapComp;
            default: return null;
            }
        }
    }

    // ── 1. Media ──
    Component {
        id: mediaComp
        Row {
            spacing: Theme.px(5)

            ClippingRectangle {
                visible: root.part === "left" || root.part === "compact"
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(20)
                height: Theme.px(20)
                radius: Theme.px(6)
                color: Qt.rgba(1, 1, 1, 0.09)
                scale: Media.playing ? 1.0 : 0.84
                opacity: Media.playing ? 1.0 : 0.65
                Behavior on scale { Spring { epsilon: 0.01 } }
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

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
                    source: (root.part === "left" || root.part === "compact") ? Media.trackArtUrl : ""
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(48, 48)
                    visible: status === Image.Ready && source !== ""
                }
            }

            AudioWave {
                visible: root.part === "right"
                anchors.verticalCenter: parent.verticalCenter
                active: Media.playing
                color: Media.playing ? Media.trackAccent : Theme.text3
                Behavior on color { ColorAnimation { duration: 280 } }
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
    }

    // ── 2. Mic Privacy / Mute ──
    Component {
        id: micComp
        Row {
            spacing: Theme.px(4)

            Rectangle {
                visible: (root.part === "left" || root.part === "compact") && !Audio.micMuted && Audio.micInUse
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(5)
                height: width
                radius: width / 2
                color: Theme.orange
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
    }

    // ── 3. Thermal / Load Alert ──
    Component {
        id: thermalComp
        Row {
            spacing: Theme.px(3)

            readonly property bool tempHot: SysInfo.cpuTemp >= LiveActivity.thermalTempThreshold
            readonly property bool cpuHot: SysInfo.highLoadAlert
            readonly property color tintColor: (SysInfo.cpuTemp >= LiveActivity.thermalCritTemp || SysInfo.mem >= LiveActivity.memCritThreshold) ? Theme.red : Theme.warn
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
    }

    // ── 4. External IPC Task ──
    Component {
        id: ipcComp
        Row {
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
    }

    // ── 5. Active System Modes ──
    Component {
        id: modesComp
        Row {
            spacing: Theme.px(4)

            readonly property string modeIcon: SysToggles.nightLight ? "bedtime"
                                             : SysToggles.gameMode ? "sports_esports"
                                             : "coffee"
            readonly property string modeLabel: SysToggles.nightLight ? (SysToggles.nightTemp + "K")
                                              : SysToggles.gameMode ? "GAME"
                                              : "AWAKE"
            readonly property color modeColor: SysToggles.nightLight ? Theme.orange
                                             : SysToggles.gameMode ? Theme.teal
                                             : Theme.yellow

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
    }

    // ── 6. Audio Output Muted ──
    Component {
        id: mutedComp
        Row {
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
    }

    // ── 7. Screen Recorder ──
    Component {
        id: recorderComp
        Row {
            spacing: Theme.px(5)

            Item {
                visible: root.part === "left" || root.part === "compact"
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(11)
                height: Theme.px(14)

                Rectangle {
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
    }

    // ── 8. Timer / Stopwatch (crisp vector ring + continuous hand) ──
    Component {
        id: timerComp
        Row {
            spacing: Theme.px(5)
            opacity: 1.0
            SequentialAnimation on opacity {
                running: Timers.running && Timers.paused
                loops: Animation.Infinite
                NumberAnimation { to: 0.45; duration: 750; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutSine }
            }

            Item {
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

                // Continuous rotation (elapsedSec * 6) avoids 354° backwards whip at 59 -> 60
                Item {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    rotation: Timers.mode === "stopwatch" ? (Timers.elapsedSec * 6) : -40
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
    }

    // ── 9. Hyprland Submap ──
    Component {
        id: submapComp
        Row {
            spacing: Theme.px(4)

            readonly property string subName: Keyboard.submap.toLowerCase()
            readonly property string subIcon: subName.indexOf("resize") !== -1 ? "open_with"
                                            : subName.indexOf("pass") !== -1 ? "lock_open"
                                            : "keyboard_command_key"

            Icon {
                visible: root.part === "left" || root.part === "compact"
                anchors.verticalCenter: parent.verticalCenter
                name: parent.subIcon
                size: Theme.px(13)
                color: Theme.orange
            }
            Text {
                visible: root.part === "right" || root.part === "compact"
                anchors.verticalCenter: parent.verticalCenter
                text: Keyboard.submap.toUpperCase()
                color: Theme.orange
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(10)
                font.weight: Font.Bold
                font.letterSpacing: Theme.px(0.4)
            }
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
