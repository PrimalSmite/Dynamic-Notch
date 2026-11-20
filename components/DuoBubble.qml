import QtQuick
import qs.services

// Detached iPhone Duo ring/pill floating to the right of the notch when 2+ Live Activities
// are active and IslandPrefs.liveActivityStyle === "duo".
Item {
    id: root

    property var host: null
    property bool compactMode: true
    property bool notchHidden: false

    readonly property var items: LiveActivity.secondaryItems
    property string _pinnedKind: ""

    readonly property bool shown: IslandPrefs.liveWingsEnabled
                               && IslandPrefs.liveActivityStyle === "duo"
                               && items.length > 0
                               && compactMode
                               && !notchHidden

    readonly property string activeKind: {
        if (items.length === 0) return "";
        if (_pinnedKind !== "") {
            const idx = items.indexOf(_pinnedKind);
            if (idx >= 0) return _pinnedKind;
        }
        return items[0];
    }

    readonly property bool _mediaShown: shown && activeKind === "media" && Media.playing
    property bool _mediaConsumerRegistered: false
    function _syncMediaConsumer() {
        if (_mediaShown && !_mediaConsumerRegistered) {
            Media.activeConsumers++;
            _mediaConsumerRegistered = true;
        } else if (!_mediaShown && _mediaConsumerRegistered) {
            Media.activeConsumers = Math.max(0, Media.activeConsumers - 1);
            _mediaConsumerRegistered = false;
        }
    }
    on_MediaShownChanged: _syncMediaConsumer()
    Component.onCompleted: _syncMediaConsumer()
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

    onItemsChanged: {
        if (items.length === 0 || (_pinnedKind !== "" && items.indexOf(_pinnedKind) < 0)) {
            _pinnedKind = "";
        }
    }

    function cycle(delta) {
        if (items.length <= 1) return;
        const cur = Math.max(0, items.indexOf(activeKind));
        const next = (cur + delta + items.length) % items.length;
        _pinnedKind = items[next];
        slotPulse.restart();
    }

    property real _slotScale: 1.0
    SpringAnimation {
        id: slotPulse
        target: root
        property: "_slotScale"
        from: 0.84
        to: 1.0
        spring: Theme.springK
        damping: Theme.springDamp
        epsilon: 0.01
    }

    readonly property real targetW: Math.max(Theme.compactH, slotContent.implicitWidth + Theme.px(18))
    width: targetW
    height: Theme.compactH
    visible: shown || opacity > 0.001

    opacity: shown ? 1.0 : 0.0
    scale: (shown ? 1.0 : 0.45) * (bubbleMa.pressed ? 0.92 : (bubbleMa.containsMouse ? 1.05 : 1.0)) * _slotScale
    property real offsetX: shown ? 0 : -Theme.px(18)
    transform: Translate { x: root.offsetX }

    Behavior on width { Spring { epsilon: 0.5 } }
    Behavior on scale { Spring { epsilon: 0.01 } }
    Behavior on offsetX { Spring { epsilon: 0.25 } }
    Behavior on opacity {
        NumberAnimation {
            duration: root.shown ? Theme.fadeIn : Theme.fadeOut
            easing.type: root.shown ? Easing.OutCubic : Easing.InQuad
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.bg
    }

    LiveSlotContent {
        id: slotContent
        anchors.centerIn: parent
        kind: root.activeKind
        part: "compact"
        mediaProgress: root.mediaProgress
        overflowCount: Math.max(0, root.items.length - 1)
    }

    MouseArea {
        id: bubbleMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root._pinnedKind = "";
                slotPulse.restart();
            } else {
                LiveActivity.openMenu(root.activeKind, root.host);
            }
        }

        property real _wheelAcc: 0
        onWheel: w => {
            if (root.items.length <= 1) return;
            _wheelAcc += w.angleDelta.y;
            if (Math.abs(_wheelAcc) < 80) return;
            root.cycle(_wheelAcc > 0 ? -1 : 1);
            _wheelAcc = 0;
        }
    }
}
