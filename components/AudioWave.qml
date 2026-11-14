import QtQuick
import qs.services

// Minimal 3-bar audio level wave for compact Live Activity media wing.
// Animates smoothly when active and settles gently at rest on pause.
Row {
    id: root

    property bool active: false
    property color color: Theme.text
    property real maxH: Theme.px(12)
    property real minH: Theme.px(3)

    spacing: Theme.px(1.5)
    height: maxH

    Repeater {
        model: [
            { duration: 360, peak: 0.72, low: 0.28 },
            { duration: 470, peak: 1.00, low: 0.35 },
            { duration: 410, peak: 0.82, low: 0.24 }
        ]

        Rectangle {
            id: bar
            required property var modelData
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(2)
            radius: width / 2
            color: root.color

            property real targetH: root.minH
            height: root.active ? targetH : root.minH

            Behavior on height {
                enabled: !root.active
                Spring { epsilon: 0.05 }
            }

            SequentialAnimation on targetH {
                running: root.active && root.visible
                loops: Animation.Infinite
                alwaysRunToEnd: false
                NumberAnimation {
                    to: root.maxH * bar.modelData.peak
                    duration: bar.modelData.duration
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: Math.max(root.minH, root.maxH * bar.modelData.low)
                    duration: bar.modelData.duration
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
