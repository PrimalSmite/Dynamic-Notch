import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services
import qs.components

// Screen recording panel with viewfinder frame, animated audio waveforms, and folder/recent controls.
// Hotkeys: Enter/Space — start/stop, S/G — Fullscreen/Area, A/M/C/F — options, O — open folder.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true

    implicitWidth: Theme.px(380)
    implicitHeight: mainCol.implicitHeight

    readonly property color warmAccent: "#DFC496"
    readonly property color slateFill: "#2A2B33"
    readonly property color slateHover: "#343640"
    readonly property color dimBarColor: "#3D3E4A"
    readonly property color recRed: "#DE5454"
    readonly property color idleGreen: "#4ADE80"

    readonly property PwNode defaultSource: Pipewire.defaultAudioSource
    PwObjectTracker { objects: root.defaultSource ? [root.defaultSource] : [] }

    readonly property real micVol: (defaultSource && defaultSource.audio)
        ? Math.max(0, Math.min(1.5, defaultSource.audio.volume))
        : 0.55
    readonly property bool micMuted: (defaultSource && defaultSource.audio)
        ? defaultSource.audio.muted
        : false

    readonly property string micName: {
        if (!defaultSource) return "Default Microphone";
        let s = defaultSource.description || defaultSource.nickname || defaultSource.name || "Microphone";
        s = s.replace(/^Family \d+h.*Audio Controller /i, "")
             .replace(/Analog Stereo/gi, "")
             .trim();
        return s || "Microphone";
    }

    // Natural waveform bar height profile (17 bars)
    readonly property var waveProfile: [
        0.36, 0.62, 0.48, 0.78, 0.52, 0.68, 0.54, 0.96,
        0.46, 0.72, 0.50, 0.84, 0.44, 0.66, 0.42, 0.58, 0.34
    ]

    property real wavePhase: 0
    Timer {
        interval: 90
        running: root.visible && (Recorder.recording || Recorder.audioMic || Recorder.audioDesktop)
        repeat: true
        onTriggered: root.wavePhase = (root.wavePhase + 0.35) % (Math.PI * 2)
    }

    Component.onCompleted: {
        Recorder.refreshRecent();
    }

    function setMicVolume(v) {
        const clamped = Math.max(0, Math.min(1, v));
        if (defaultSource && defaultSource.audio) {
            defaultSource.audio.muted = false;
            defaultSource.audio.volume = clamped;
        } else {
            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", clamped.toFixed(2)]);
        }
    }

    function toggleRec() {
        if (Recorder.recording) {
            Recorder.stop();
        } else {
            const mon = (root.host && root.host.monitor && root.host.monitor.name) ? root.host.monitor.name : "screen";
            if (root.host) root.host.collapse();
            Recorder.start(mon);
        }
    }

    function openRecordingsDir() {
        Quickshell.execDetached(["sh", "-c", "mkdir -p '" + Recorder.outDir + "' && xdg-open '" + Recorder.outDir + "' >/dev/null 2>&1 &"]);
    }

    Keys.onPressed: event => {
        const t = (event.text || "").toLowerCase();
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            toggleRec();
            event.accepted = true;
        } else if (event.key === Qt.Key_O || t === "o" || t === "щ") {
            openRecordingsDir();
            event.accepted = true;
        } else if (!Recorder.recording) {
            if (event.key === Qt.Key_S || t === "s" || t === "ы") { Recorder.target = "screen"; event.accepted = true; }
            else if (event.key === Qt.Key_G || t === "g" || t === "п") { Recorder.target = "region"; event.accepted = true; }
            else if (event.key === Qt.Key_A || t === "a" || t === "ф") { Recorder.audioDesktop = !Recorder.audioDesktop; event.accepted = true; }
            else if (event.key === Qt.Key_M || t === "m" || t === "ь") { Recorder.audioMic = !Recorder.audioMic; event.accepted = true; }
            else if (event.key === Qt.Key_C || t === "c" || t === "с") { Recorder.showCursor = !Recorder.showCursor; event.accepted = true; }
            else if (event.key === Qt.Key_F || t === "f") { Recorder.fps = (Recorder.fps === 60 ? 30 : 60); event.accepted = true; }
        }
    }

    Column {
        id: mainCol
        width: parent.width
        spacing: Theme.px(12)

        // ── 1. Top Header: < RECORD on left, ● IDLE / REC on right ──
        Item {
            width: parent.width
            height: Theme.px(24)

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(10)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevron_left"
                    size: Theme.px(16)
                    color: backMa.containsMouse ? Theme.text : Theme.text2
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "RECORD"
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                    font.weight: Font.Medium
                    font.letterSpacing: 3.2
                }
            }

            MouseArea {
                id: backMa
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(100)
                height: parent.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.host) root.host.backToDashboard();
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(7)

                Rectangle {
                    id: statusDot
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(8)
                    height: width
                    radius: width / 2
                    color: Recorder.recording ? root.recRed : root.idleGreen
                    Behavior on color { ColorAnimation { duration: 200 } }

                    SequentialAnimation on opacity {
                        running: Recorder.recording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 650; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 650; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Recorder.recording ? ("REC · " + Recorder.elapsedText) : "IDLE"
                    color: Recorder.recording ? root.recRed : Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                    font.weight: Font.Medium
                    font.letterSpacing: 1.8
                    font.features: { "tnum": 1 }
                }
            }
        }

        // ── 2. Viewfinder Frame Box: Screen recorder + 60 fps · High quality · Fullscreen ──
        Item {
            id: viewfinderBox
            width: parent.width
            height: Theme.px(76)

            readonly property real bracketLen: Theme.px(14)
            readonly property real bracketThick: Math.max(1.5, Theme.px(1.5))
            readonly property color bracketColor: vfMa.containsMouse
                ? Qt.rgba(1, 1, 1, 0.55)
                : Qt.rgba(1, 1, 1, 0.32)

            // Top-Left corner bracket ┌
            Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: viewfinderBox.bracketLen; height: viewfinderBox.bracketThick; color: viewfinderBox.bracketColor; Behavior on color { ColorAnimation { duration: 160 } } }
            Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: viewfinderBox.bracketThick; height: viewfinderBox.bracketLen; color: viewfinderBox.bracketColor; Behavior on color { ColorAnimation { duration: 160 } } }

            // Top-Right corner bracket ┐
            Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: viewfinderBox.bracketLen; height: viewfinderBox.bracketThick; color: viewfinderBox.bracketColor; Behavior on color { ColorAnimation { duration: 160 } } }
            Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: viewfinderBox.bracketThick; height: viewfinderBox.bracketLen; color: viewfinderBox.bracketColor; Behavior on color { ColorAnimation { duration: 160 } } }

            // Bottom-Left corner bracket └
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; width: viewfinderBox.bracketLen; height: viewfinderBox.bracketThick; color: viewfinderBox.bracketColor; Behavior on color { ColorAnimation { duration: 160 } } }
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; width: viewfinderBox.bracketThick; height: viewfinderBox.bracketLen; color: viewfinderBox.bracketColor; Behavior on color { ColorAnimation { duration: 160 } } }

            // Bottom-Right corner bracket ┘
            Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: viewfinderBox.bracketLen; height: viewfinderBox.bracketThick; color: viewfinderBox.bracketColor; Behavior on color { ColorAnimation { duration: 160 } } }
            Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: viewfinderBox.bracketThick; height: viewfinderBox.bracketLen; color: viewfinderBox.bracketColor; Behavior on color { ColorAnimation { duration: 160 } } }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(18)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(4)

                Text {
                    text: "Screen recorder"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(18)
                    font.weight: Font.Bold
                }

                Text {
                    text: Recorder.fps + " fps · "
                        + (Recorder.showCursor ? "High quality" : "Cursor hidden")
                        + " · "
                        + (Recorder.target === "screen" ? "Fullscreen" : "Record area")
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(12)
                }
            }

            MouseArea {
                id: vfMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: !Recorder.recording
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Recorder.fps = (Recorder.fps === 60 ? 30 : 60);
                }
                onPressAndHold: {
                    Recorder.showCursor = !Recorder.showCursor;
                }
            }
        }

        // ── 3. Target Selection Row: [ Fullscreen ]  [ Record area ] ──
        Row {
            width: parent.width
            spacing: Theme.px(10)
            readonly property real btnW: (width - spacing) / 2

            Repeater {
                model: [
                    { key: "screen", label: "Fullscreen", icon: "desktop_windows" },
                    { key: "region", label: "Record area", icon: "crop" }
                ]

                Rectangle {
                    id: modeBtn
                    required property var modelData
                    readonly property bool active: Recorder.target === modelData.key
                    width: parent.btnW
                    height: Theme.px(42)
                    radius: Theme.px(12)
                    color: active
                        ? (modeMa.containsMouse ? root.slateHover : root.slateFill)
                        : (modeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                    border.width: 1
                    border.color: active ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.14)
                    scale: modeMa.pressed ? 0.95 : (modeMa.containsMouse ? 1.015 : 1.0)

                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }
                    Behavior on scale { Spring { epsilon: 0.01 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(8)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: modeBtn.modelData.icon
                            size: Theme.px(16)
                            color: modeBtn.active ? root.warmAccent : Theme.text2
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modeBtn.modelData.label
                            color: modeBtn.active ? root.warmAccent : Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: modeBtn.active ? Font.DemiBold : Font.Medium
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                    }

                    MouseArea {
                        id: modeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !Recorder.recording
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Recorder.target = modeBtn.modelData.key
                    }
                }
            }
        }

        // ── 4. Main Pill Action Button: [ ● Start recording ] ──
        Rectangle {
            id: startPill
            width: parent.width
            height: Theme.px(46)
            radius: height / 2
            color: Recorder.recording
                ? (startRecMa.containsMouse ? Qt.rgba(0.87, 0.33, 0.33, 0.32) : Qt.rgba(0.87, 0.33, 0.33, 0.22))
                : (startRecMa.containsMouse ? root.slateHover : root.slateFill)
            border.width: Recorder.recording ? 1 : 0
            border.color: root.recRed
            scale: startRecMa.pressed ? 0.96 : (startRecMa.containsMouse ? 1.015 : 1.0)

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { Spring { epsilon: 0.01 } }

            Row {
                anchors.centerIn: parent
                spacing: Theme.px(10)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(12)
                    height: width
                    radius: Recorder.recording ? Theme.px(3) : width / 2
                    color: root.recRed
                    Behavior on radius { NumberAnimation { duration: 160 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Recorder.recording
                        ? ("Stop recording · " + Recorder.elapsedText)
                        : "Start recording"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(14)
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
            }

            MouseArea {
                id: startRecMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleRec()
            }
        }

        // ── 5. Audio Controls with Interactive Animated Waveforms ──
        Column {
            width: parent.width
            spacing: Theme.px(10)

            // Row 1: Microphone Input + Waveform + %
            Item {
                width: parent.width
                height: Theme.px(28)

                Row {
                    id: micLeftRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(7)
                    width: Theme.px(148)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: (Recorder.audioMic && !root.micMuted) ? "mic" : "mic_off"
                        size: Theme.px(16)
                        color: (Recorder.audioMic && !root.micMuted) ? root.warmAccent : Theme.text3
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.micName
                        color: Recorder.audioMic ? Theme.text : Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        width: Theme.px(106)
                        elide: Text.ElideRight
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "expand_more"
                        size: Theme.px(13)
                        color: Theme.text3
                    }
                }

                MouseArea {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: micLeftRow.width
                    height: parent.height
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Recorder.audioMic = !Recorder.audioMic
                }

                // Mic Interactive Waveform Bars
                Item {
                    id: micWaveBox
                    anchors.left: micLeftRow.right
                    anchors.right: micPctText.left
                    anchors.leftMargin: Theme.px(10)
                    anchors.rightMargin: Theme.px(10)
                    anchors.verticalCenter: parent.verticalCenter
                    height: Theme.px(22)

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(3.5)

                        Repeater {
                            model: 17
                            Rectangle {
                                required property int index
                                readonly property real normPos: (index + 0.5) / 17.0
                                readonly property bool isLit: Recorder.audioMic && !root.micMuted && (normPos <= root.micVol + 0.02)
                                readonly property real baseH: root.waveProfile[index] || 0.5
                                readonly property real animMod: (Recorder.recording && isLit)
                                    ? (1.0 + 0.18 * Math.sin(root.wavePhase + index * 0.65))
                                    : 1.0

                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(2.8)
                                height: Math.max(Theme.px(4), Theme.px(18) * baseH * animMod)
                                radius: width / 2
                                color: isLit ? root.warmAccent : root.dimBarColor

                                Behavior on height { NumberAnimation { duration: 90 } }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => {
                            Recorder.audioMic = true;
                            root.setMicVolume(mouse.x / width);
                        }
                        onPositionChanged: mouse => {
                            if (pressed) root.setMicVolume(mouse.x / width);
                        }
                        onWheel: w => {
                            Recorder.audioMic = true;
                            root.setMicVolume(root.micVol + (w.angleDelta.y > 0 ? 0.05 : -0.05));
                        }
                    }
                }

                Text {
                    id: micPctText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(38)
                    horizontalAlignment: Text.AlignRight
                    text: (Recorder.audioMic && !root.micMuted) ? (Math.round(root.micVol * 100) + "%") : "Off"
                    color: Recorder.audioMic ? Theme.text2 : Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(12)
                    font.features: { "tnum": 1 }
                }
            }

            // Row 2: Desktop Audio + Waveform + %
            Item {
                width: parent.width
                height: Theme.px(28)

                Row {
                    id: deskLeftRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(7)
                    width: Theme.px(148)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: (Recorder.audioDesktop && !Audio.muted) ? "volume_up" : "volume_off"
                        size: Theme.px(16)
                        color: (Recorder.audioDesktop && !Audio.muted) ? root.warmAccent : Theme.text3
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Desktop"
                        color: Recorder.audioDesktop ? Theme.text : Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                    }
                }

                MouseArea {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: deskLeftRow.width
                    height: parent.height
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Recorder.audioDesktop = !Recorder.audioDesktop
                }

                // Desktop Interactive Waveform Bars
                Item {
                    id: deskWaveBox
                    anchors.left: deskLeftRow.right
                    anchors.right: deskPctText.left
                    anchors.leftMargin: Theme.px(10)
                    anchors.rightMargin: Theme.px(10)
                    anchors.verticalCenter: parent.verticalCenter
                    height: Theme.px(22)

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(3.5)

                        Repeater {
                            model: 17
                            Rectangle {
                                required property int index
                                readonly property real normPos: (index + 0.5) / 17.0
                                readonly property bool isLit: Recorder.audioDesktop && !Audio.muted && (normPos <= Audio.volume + 0.02)
                                readonly property real baseH: root.waveProfile[(index + 4) % 17] || 0.5
                                readonly property real animMod: (Recorder.recording && isLit)
                                    ? (1.0 + 0.18 * Math.cos(root.wavePhase + index * 0.55))
                                    : 1.0

                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(2.8)
                                height: Math.max(Theme.px(4), Theme.px(18) * baseH * animMod)
                                radius: width / 2
                                color: isLit ? root.warmAccent : root.dimBarColor

                                Behavior on height { NumberAnimation { duration: 90 } }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => {
                            Recorder.audioDesktop = true;
                            Audio.setVolume(mouse.x / width);
                        }
                        onPositionChanged: mouse => {
                            if (pressed) Audio.setVolume(mouse.x / width);
                        }
                        onWheel: w => {
                            Recorder.audioDesktop = true;
                            Audio.step(w.angleDelta.y > 0 ? 0.05 : -0.05);
                        }
                    }
                }

                Text {
                    id: deskPctText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(38)
                    horizontalAlignment: Text.AlignRight
                    text: (Recorder.audioDesktop && !Audio.muted) ? (Math.round(Audio.volume * 100) + "%") : "Off"
                    color: Recorder.audioDesktop ? Theme.text2 : Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(12)
                    font.features: { "tnum": 1 }
                }
            }
        }

        // ── 6. Output Folder Bar: [ 📁 ~/Videos/Recordings          (OPEN) ] ──
        Rectangle {
            width: parent.width
            height: Theme.px(38)
            radius: Theme.px(12)
            color: "#0C0D10"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(8)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "folder"
                    size: Theme.px(15)
                    color: Theme.text3
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "~/Videos/Recordings"
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(12)
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(8)
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.px(24)
                width: openBtnText.implicitWidth + Theme.px(18)
                radius: height / 2
                color: openMa.containsMouse ? Qt.rgba(223, 196, 150, 0.16) : "transparent"
                border.width: 1
                border.color: Qt.rgba(223, 196, 150, 0.45)
                scale: openMa.pressed ? 0.93 : 1.0
                Behavior on scale { Spring { epsilon: 0.01 } }
                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    id: openBtnText
                    anchors.centerIn: parent
                    text: "OPEN"
                    color: root.warmAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(10)
                    font.weight: Font.Bold
                    font.letterSpacing: 0.6
                }

                MouseArea {
                    id: openMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openRecordingsDir()
                }
            }
        }

        // ── 7. Recent Recordings Section ──
        Column {
            width: parent.width
            spacing: Theme.px(8)

            Text {
                text: "RECENT · " + Recorder.recentFiles.length
                color: Theme.text3
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(10)
                font.weight: Font.DemiBold
                font.letterSpacing: 2.0
            }

            // Empty state
            Item {
                visible: Recorder.recentFiles.length === 0
                width: parent.width
                height: Theme.px(28)

                Text {
                    anchors.centerIn: parent
                    text: "No recent recordings"
                    color: Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(12)
                }
            }

            // Recent files list (up to 2 compact rows)
            Column {
                visible: Recorder.recentFiles.length > 0
                width: parent.width
                spacing: Theme.px(4)

                Repeater {
                    model: Recorder.recentFiles.slice(0, 2)
                    Rectangle {
                        id: recRow
                        required property string modelData
                        width: parent.width
                        height: Theme.px(28)
                        radius: Theme.px(8)
                        color: recItemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.px(10)
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.px(10)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.px(8)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "play_circle"
                                size: Theme.px(14)
                                color: root.warmAccent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: recRow.modelData.split("/").pop() || recRow.modelData
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(11)
                                width: parent.width - Theme.px(26)
                                elide: Text.ElideMiddle
                            }
                        }

                        MouseArea {
                            id: recItemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["xdg-open", recRow.modelData])
                        }
                    }
                }
            }
        }
    }
}
