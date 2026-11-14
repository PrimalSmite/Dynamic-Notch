import QtQuick
import Quickshell.Widgets
import qs.services

// Live Activity wing for the outer left or right edge of the compact notch.
// Blends directly into the notch background (no borders or boxes) with iOS spring transitions,
// mouse-wheel queue cycling when multiple activities are active, and +N overflow indicator.
Item {
    id: root

    property string side: "left"         // "left" | "right"
    property var host: null              // Island PanelWindow
    property real homeProgress: 0        // 0 = compact, 1 = dashboard
    property real compactAlpha: 1
    property bool notchHovered: false

    readonly property var items: side === "left" ? LiveActivity.leftItems : LiveActivity.rightItems
    property int selectedIndex: 0
    property string _pinnedKind: ""

    readonly property bool active: items.length > 0
    readonly property string activeKind: {
        if (items.length === 0) return "";
        if (_pinnedKind !== "") {
            const idx = items.indexOf(_pinnedKind);
            if (idx >= 0) return _pinnedKind;
        }
        return items[0];
    }

    onItemsChanged: {
        if (items.length === 0) {
            _pinnedKind = "";
            selectedIndex = 0;
        } else if (_pinnedKind !== "" && items.indexOf(_pinnedKind) < 0) {
            _pinnedKind = "";
            selectedIndex = 0;
        }
    }

    // Track Media progress lazily ONLY when media wing is actively shown & playing
    readonly property bool _mediaShown: active && activeKind === "media" && homeProgress < 0.5
    property bool _mediaConsumerRegistered: false
    on_MediaShownChanged: {
        if (_mediaShown && !_mediaConsumerRegistered) {
            Media.activeConsumers++;
            _mediaConsumerRegistered = true;
        } else if (!_mediaShown && _mediaConsumerRegistered) {
            Media.activeConsumers = Math.max(0, Media.activeConsumers - 1);
            _mediaConsumerRegistered = false;
        }
    }
    Component.onDestruction: {
        if (_mediaConsumerRegistered) {
            Media.activeConsumers = Math.max(0, Media.activeConsumers - 1);
            _mediaConsumerRegistered = false;
        }
    }

    readonly property real mediaProgress: {
        const p = Media.player;
        if (!p || !p.length || p.length <= 0) return 0;
        return Math.max(0, Math.min(1, p.position / p.length));
    }

    readonly property real compactW: active ? (wingRow.implicitWidth + Theme.px(8)) : 0
    readonly property real dashW: 0

    width: Math.max(0, compactW * (1 - homeProgress))
    height: Theme.px(38)
    opacity: active ? compactAlpha : 0
    clip: true

    Behavior on opacity {
        NumberAnimation { duration: Theme.fadeIn; easing.type: Easing.OutCubic }
    }

    function cycle(delta) {
        if (items.length <= 1) return;
        const cur = Math.max(0, items.indexOf(activeKind));
        const next = (cur + delta + items.length) % items.length;
        selectedIndex = next;
        _pinnedKind = items[next];
        slotPulse.restart();
    }

    function handleLeftClick() {
        if (!activeKind) return;
        if (activeKind === "media") {
            Media.togglePlay();
        } else if (activeKind === "ipc") {
            if (LiveActivity.ipcTask && LiveActivity.ipcTask.done) {
                LiveActivity.clearTask();
            }
        } else if (activeKind === "clipboard") {
            Clipboard.dismissRecentCopy();
            if (host) host.openPanel("clipboard");
        } else if (activeKind === "mic") {
            Audio.toggleMic();
        } else if (activeKind === "thermal") {
            if (host) host.openPanel("sysmon");
        } else if (activeKind === "modes") {
            if (SysToggles.keepAwake) SysToggles.toggleKeepAwake();
            else if (SysToggles.nightLight) SysToggles.toggleNightLight();
            else if (SysToggles.gameMode) SysToggles.toggleGameMode();
        } else if (activeKind === "muted") {
            Audio.toggleMute();
        } else if (activeKind === "caps") {
            // Informational indicator; right-click opens settings if desired
        }
    }

    function handleRightClick() {
        if (!activeKind) return;
        if (activeKind === "media") {
            if (host) host.openPanel("media");
        } else if (activeKind === "ipc") {
            LiveActivity.clearTask();
        } else if (activeKind === "clipboard") {
            Clipboard.dismissRecentCopy();
        } else if (activeKind === "mic" || activeKind === "muted") {
            if (host) host.openPanel("mixer");
        } else if (activeKind === "thermal") {
            if (host) host.openPanel("sysmon");
        } else if (activeKind === "modes" || activeKind === "caps") {
            if (host) host.openPanel("settings");
        }
    }

    // Subtle iOS spring pulse on slot switch
    property real _slotScale: 1.0
    SpringAnimation {
        id: slotPulse
        target: root
        property: "_slotScale"
        from: 0.86
        to: 1.0
        spring: Theme.springK
        damping: Theme.springDamp
        epsilon: 0.01
    }

    Row {
        id: wingRow
        anchors.left: root.side === "right" ? parent.left : undefined
        anchors.right: root.side === "left" ? parent.right : undefined
        anchors.leftMargin: root.side === "right" ? Theme.px(4) : 0
        anchors.rightMargin: root.side === "left" ? Theme.px(4) : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(7)

        // Divider on the inner edge of the right wing
        Rectangle {
            visible: root.side === "right"
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: Theme.px(14)
            color: Theme.divider
        }

        // Interactive content block
        Item {
            id: contentBox
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: contentRow.implicitWidth
            implicitHeight: Theme.px(24)
            width: implicitWidth
            height: implicitHeight

            scale: (wingMa.pressed ? 0.92 : (wingMa.containsMouse ? 1.05 : 1.0)) * root._slotScale
            Behavior on scale { Spring { epsilon: 0.01 } }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: Theme.px(5)

                // ── LEFT: 1. Media Now Playing ──
                Row {
                    visible: root.activeKind === "media"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(5)

                    ClippingRectangle {
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
                            visible: !wingArt.visible
                        }
                        Image {
                            id: wingArt
                            anchors.fill: parent
                            source: Media.trackArtUrl
                            cache: false
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(48, 48)
                            visible: status === Image.Ready && source !== ""
                        }

                        // Subtle bottom progress hairline inside artwork
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
                        anchors.verticalCenter: parent.verticalCenter
                        active: Media.playing
                        color: Media.playing ? Theme.text : Theme.text3
                        maxH: Theme.px(11)
                        minH: Theme.px(3)
                    }

                    Text {
                        visible: (IslandPrefs.liveMediaShowTitle || root.notchHovered) && Media.trackTitle !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, Theme.px(76))
                        elide: Text.ElideRight
                        text: Media.trackTitle
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                        font.weight: Font.Medium
                    }
                }

                // ── LEFT: 2. External IPC Task ──
                Row {
                    visible: root.activeKind === "ipc" && LiveActivity.ipcTask !== null
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(5)

                    ProgressRing {
                        visible: LiveActivity.ipcTask ? !LiveActivity.ipcTask.done : false
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.px(14)
                        strokeWidth: Theme.px(1.8)
                        indeterminate: LiveActivity.ipcTask ? (LiveActivity.ipcTask.progress < 0) : true
                        value: LiveActivity.ipcTask ? Math.max(0, LiveActivity.ipcTask.progress) : 0
                        fillColor: Theme.text
                    }

                    Icon {
                        visible: LiveActivity.ipcTask ? !!LiveActivity.ipcTask.done : false
                        anchors.verticalCenter: parent.verticalCenter
                        name: (LiveActivity.ipcTask && LiveActivity.ipcTask.ok) ? "check_circle" : "error"
                        size: Theme.px(14)
                        color: (LiveActivity.ipcTask && LiveActivity.ipcTask.ok) ? Theme.green : Theme.red
                    }

                    Text {
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

                // ── LEFT: 3. Clipboard Pulse ──
                Row {
                    visible: root.activeKind === "clipboard"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(4)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "content_paste"
                        size: Theme.px(13)
                        color: Theme.text
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Copied"
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                        font.weight: Font.DemiBold
                    }
                }

                // ── RIGHT: 1. Mic Privacy / Mute ──
                Row {
                    visible: root.activeKind === "mic"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(4)

                    Rectangle {
                        visible: !Audio.micMuted && Audio.micInUse
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(5)
                        height: width
                        radius: width / 2
                        color: Theme.orange

                        SequentialAnimation on opacity {
                            running: !Audio.micMuted && Audio.micInUse && root.activeKind === "mic"
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 750; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutSine }
                        }
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Audio.micMuted ? "mic_off" : "mic"
                        size: Theme.px(13)
                        color: Audio.micMuted ? Theme.red : Theme.orange
                    }
                }

                // ── RIGHT: 2. Thermal / Resource Alert ──
                Row {
                    visible: root.activeKind === "thermal"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(3)

                    readonly property bool tempHot: SysInfo.cpuTemp >= 80
                    readonly property bool cpuHot: SysInfo.highLoadAlert

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: parent.tempHot ? "local_fire_department" : "memory"
                        size: Theme.px(13)
                        color: (SysInfo.cpuTemp >= 90 || SysInfo.mem >= 0.94) ? Theme.red : Theme.warn
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.tempHot ? (SysInfo.cpuTemp + "°")
                            : parent.cpuHot ? (Math.round(SysInfo.cpu * 100) + "%")
                            : (Math.round(SysInfo.mem * 100) + "%")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                }

                // ── RIGHT: 3. Active System Modes ──
                Icon {
                    visible: root.activeKind === "modes"
                    anchors.verticalCenter: parent.verticalCenter
                    name: SysToggles.keepAwake ? "coffee"
                        : SysToggles.nightLight ? "bedtime"
                        : "sports_esports"
                    size: Theme.px(13)
                    color: SysToggles.keepAwake ? Theme.yellow
                         : SysToggles.nightLight ? Theme.orange
                         : Theme.teal
                }

                // ── RIGHT: 4. Audio Output Muted ──
                Icon {
                    visible: root.activeKind === "muted"
                    anchors.verticalCenter: parent.verticalCenter
                    name: "volume_off"
                    size: Theme.px(13)
                    color: Theme.red
                }

                // ── RIGHT: 5. Caps Lock ──
                Text {
                    visible: root.activeKind === "caps"
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CAPS"
                    color: Theme.warn
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(10)
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.px(0.5)
                }

                // Subtle overflow counter (+N) when multiple activities share this wing
                Text {
                    visible: root.items.length > 1
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+" + (root.items.length - 1)
                    color: Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(10)
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }

            MouseArea {
                id: wingMa
                anchors.fill: parent
                anchors.margins: Theme.px(-4)
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        root._pinnedKind = "";
                        root.selectedIndex = 0;
                        slotPulse.restart();
                    } else if (mouse.button === Qt.RightButton) {
                        root.handleRightClick();
                    } else {
                        root.handleLeftClick();
                    }
                }

                property real _wheelAcc: 0
                onWheel: w => {
                    if (root.items.length > 1) {
                        _wheelAcc += w.angleDelta.y;
                        if (Math.abs(_wheelAcc) < 80) return;
                        root.cycle(_wheelAcc > 0 ? -1 : 1);
                        _wheelAcc = 0;
                    } else if (root.activeKind === "media") {
                        Audio.step(w.angleDelta.y > 0 ? 0.03 : -0.03);
                    }
                }
            }
        }

        // Divider on the inner edge of the left wing
        Rectangle {
            visible: root.side === "left"
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: Theme.px(14)
            color: Theme.divider
        }
    }
}
