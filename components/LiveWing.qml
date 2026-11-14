import QtQuick
import qs.services

// Live Activity wing inside the compact notch.
// - 1 active widget: splits symmetrically across left wing (part: "left") and right wing (part: "right")
// - 2+ active widgets:
//     * "inline" style: left wing shows primary ("compact"), right wing shows secondary ("compact") with wheel cycling
//     * "duo" style:    left wing shows primary ("left" for media, else "compact"), right wing collapses (secondary moves to DuoBubble)
Item {
    id: root

    property string side: "left"         // "left" | "right"
    property var host: null
    property real homeProgress: 0
    property real compactAlpha: 1
    property bool notchHovered: false

    readonly property bool isDuo: IslandPrefs.liveActivityStyle === "duo"
    readonly property var allItems: LiveActivity.activeItems
    readonly property var secItems: LiveActivity.secondaryItems

    property int selectedIndex: 0
    property string _pinnedKind: ""

    readonly property string activeKind: {
        if (!IslandPrefs.liveWingsEnabled || allItems.length === 0) return "";
        if (side === "left") return LiveActivity.primaryKind;

        // Right side:
        if (LiveActivity.isSplitMode) return LiveActivity.primaryKind;
        if (isDuo) return ""; // secondary widget is shown in detached DuoBubble
        if (secItems.length === 0) return "";
        if (_pinnedKind !== "" && secItems.indexOf(_pinnedKind) >= 0) return _pinnedKind;
        return secItems[0];
    }

    readonly property string slotPart: {
        if (activeKind === "") return "compact";
        if (LiveActivity.isSplitMode) return side;
        if (side === "left" && isDuo && activeKind === "media") return "left";
        return "compact";
    }

    readonly property int overflowCount: {
        if (side === "right" && !LiveActivity.isSplitMode && !isDuo && secItems.length > 1) {
            return secItems.length - 1;
        }
        return 0;
    }

    readonly property bool active: activeKind !== ""

    onSecItemsChanged: {
        if (secItems.length === 0 || (_pinnedKind !== "" && secItems.indexOf(_pinnedKind) < 0)) {
            _pinnedKind = "";
            selectedIndex = 0;
        }
    }

    // Track Media progress lazily ONLY when media is actively playing on left wing
    readonly property bool _mediaShown: active && activeKind === "media" && Media.playing && homeProgress < 0.5 && side === "left"
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

    readonly property real compactW: active ? wingRow.implicitWidth : 0
    readonly property real dashW: 0

    width: Math.max(0, compactW * (1 - homeProgress))
    height: Theme.px(38)
    opacity: active ? compactAlpha : 0
    visible: active && homeProgress < 0.99
    clip: true

    function cycleSecondary(delta) {
        if (secItems.length <= 1) return;
        const cur = Math.max(0, secItems.indexOf(activeKind));
        const next = (cur + delta + secItems.length) % secItems.length;
        selectedIndex = next;
        _pinnedKind = secItems[next];
        slotPulse.restart();
    }

    property real _slotScale: 1.0
    property string _prevKind: ""

    onActiveKindChanged: {
        if (_prevKind !== "" && activeKind !== "" && _prevKind !== activeKind) {
            slotPulse.restart();
            slotFade.restart();
        }
        _prevKind = activeKind;
    }

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

    NumberAnimation {
        id: slotFade
        target: contentBox
        property: "opacity"
        from: 0.2
        to: 1.0
        duration: 180
        easing.type: Easing.OutCubic
    }

    Row {
        id: wingRow
        anchors.centerIn: parent
        spacing: Theme.px(7)

        Item {
            id: contentBox
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: slotContent.implicitWidth
            implicitHeight: Theme.px(24)
            width: implicitWidth
            height: implicitHeight

            scale: (wingMa.pressed ? 0.92 : 1.0) * root._slotScale
            Behavior on scale { Spring { epsilon: 0.01 } }

            LiveSlotContent {
                id: slotContent
                anchors.centerIn: parent
                kind: root.activeKind
                part: root.slotPart
                notchHovered: root.notchHovered
                mediaProgress: root.mediaProgress
                overflowCount: root.overflowCount
            }

            MouseArea {
                id: wingMa
                anchors.fill: parent
                anchors.margins: Theme.px(-4)
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton && root.side === "right") {
                        root._pinnedKind = "";
                        root.selectedIndex = 0;
                        slotPulse.restart();
                    } else {
                        LiveActivity.openMenu(root.activeKind, root.host);
                    }
                }

                property real _wheelAcc: 0
                onWheel: w => {
                    if (root.side === "right" && !LiveActivity.isSplitMode && !root.isDuo && root.secItems.length > 1) {
                        _wheelAcc += w.angleDelta.y;
                        if (Math.abs(_wheelAcc) < 80) return;
                        root.cycleSecondary(_wheelAcc > 0 ? -1 : 1);
                        _wheelAcc = 0;
                    }
                }
            }
        }
    }
}
