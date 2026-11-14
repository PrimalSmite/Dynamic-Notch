import QtQuick
import qs.services

// 4-band audio-reactive wave for compact Live Activity media wing.
// Driven by Spectrum (cava at 12 Hz) when active & visible, with smooth fade-out when silent/paused.
Row {
    id: root

    property bool active: false
    property color color: Theme.text
    property real maxH: Theme.px(12)
    property real minH: Theme.px(3)

    spacing: Theme.px(1.5)
    height: maxH

    readonly property bool _consume: root.active && root.visible
    property bool _registered: false

    on_ConsumeChanged: {
        if (_consume && !_registered) {
            Spectrum.activeConsumers++;
            _registered = true;
        } else if (!_consume && _registered) {
            Spectrum.activeConsumers = Math.max(0, Spectrum.activeConsumers - 1);
            _registered = false;
        }
    }

    Component.onDestruction: {
        if (_registered) {
            Spectrum.activeConsumers = Math.max(0, Spectrum.activeConsumers - 1);
            _registered = false;
        }
    }

    Repeater {
        model: 4

        Rectangle {
            required property int index
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(2)
            radius: width / 2
            color: root.color

            readonly property real _lvl: (root.active && Spectrum.levels.length > index) ? Spectrum.levels[index] : 0
            readonly property real _shaped: Math.pow(Math.max(0, Math.min(1, _lvl)), 1.4)
            height: root.minH + (root.maxH - root.minH) * _shaped

            Behavior on height {
                enabled: !root.active || _lvl === 0
                Spring { epsilon: 0.03 }
            }
        }
    }
}
