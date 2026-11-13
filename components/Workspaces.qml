import QtQuick
import Quickshell.Hyprland
import qs.services

// Workspace indicators: vertical capsules with a subtle glow on the active workspace.
Row {
    id: root

    property var monitor: null           // HyprlandMonitor
    property real pillW: Theme.px(5)
    property real activeW: Theme.px(6)
    property real pillH: Theme.px(10)
    property real activeH: Theme.px(14)
    property color activeColor: Theme.text
    spacing: Theme.px(5)

    readonly property int activeId: (monitor && monitor.activeWorkspace && monitor.activeWorkspace.id) ? monitor.activeWorkspace.id : 1
    readonly property var wsList: (root.visible && root.opacity > 0.01) ? Hyprland.workspaces.values : []
    readonly property var occupied: {
        const s = {};
        for (const w of wsList)
            if (w.id > 0 && (!w.toplevels || w.toplevels.values.length > 0)) s[w.id] = true;
        return s;
    }
    readonly property int count: Theme.minWorkspaces
    readonly property int startId: Math.max(1, activeId - count + 1)

    function go(id) {
        id = Math.max(1, Math.min(10, id));
        if (id !== activeId) {
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
        }
    }

    Repeater {
        model: root.count

        Item {
            id: d
            required property int index
            readonly property int wsId: root.startId + index
            readonly property bool active: wsId === root.activeId
            readonly property bool busy: root.occupied[wsId] === true

            anchors.verticalCenter: parent.verticalCenter
            width: active ? root.activeW : root.pillW
            height: active ? root.activeH : root.pillH
            Behavior on width { Spring { epsilon: 0.5 } }
            Behavior on height { Spring { epsilon: 0.5 } }

            // Soft outer glow halo (active capsule only)
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + Theme.px(6)
                height: parent.height + Theme.px(6)
                radius: width / 2
                color: root.activeColor
                opacity: d.active ? 0.14 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
            }

            // Inner glow halo
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + Theme.px(3)
                height: parent.height + Theme.px(3)
                radius: width / 2
                color: root.activeColor
                opacity: d.active ? 0.26 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
            }

            // The vertical capsule itself
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: d.active ? root.activeColor : Theme.text
                Behavior on color { ColorAnimation { duration: 200 } }
                opacity: d.active ? 1 : d.busy ? 0.45 : 0.24
                scale: ma.containsMouse && !d.active ? 1.18 : 1
                Behavior on opacity { NumberAnimation { duration: 220 } }
                Behavior on scale { Spring { epsilon: 0.01 } }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                anchors.margins: Theme.px(-3)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.go(d.wsId)
            }
        }
    }
}
