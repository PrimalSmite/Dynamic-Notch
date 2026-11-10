import QtQuick
import qs.services

// Progress bar; draggable when interactive.
Item {
    id: root
    property real value: 0
    property color tint: Theme.text
    property bool interactive: false
    readonly property bool dragging: ma.pressed
    signal moved(real v)

    implicitHeight: Theme.px(6)
    readonly property real clamped: Math.max(0, Math.min(1, value))

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.track
    }
    Rectangle {
        height: parent.height
        radius: height / 2
        width: root.clamped > 0.001 ? Math.max(height, parent.width * root.clamped) : 0
        color: root.tint
        Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: Theme.px(-8)
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        function send(mx) { root.moved(Math.max(0, Math.min(1, (mx + ma.x) / root.width))); }
        onPressed: e => send(e.x)
        onPositionChanged: e => { if (pressed) send(e.x); }
    }
}
