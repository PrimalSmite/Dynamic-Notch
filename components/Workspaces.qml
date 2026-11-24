import QtQuick
import Quickshell.Hyprland
import qs.services

// Workspace indicators: vertical capsules with a subtle glow on the active workspace.
Item {
    id: root

    property var monitor: null           // HyprlandMonitor
    property real pillW: Theme.px(5)
    property real activeW: Theme.px(6)
    property real pillH: Theme.px(10)
    property real activeH: Theme.px(14)
    property color activeColor: Theme.text
    property real spacing: Theme.px(5)

    readonly property int activeId: (monitor && monitor.activeWorkspace && monitor.activeWorkspace.id) ? monitor.activeWorkspace.id : 1
    readonly property var wsList: Hyprland.workspaces ? Hyprland.workspaces.values : []
    readonly property var occupied: {
        const s = {};
        const monName = monitor ? monitor.name : "";
        for (const w of wsList) {
            if (w.id <= 0) continue;
            if (monName && w.monitor && w.monitor.name && w.monitor.name !== monName) continue;
            if (!w.toplevels || w.toplevels.values.length > 0) s[w.id] = true;
        }
        return s;
    }
    readonly property int count: Theme.minWorkspaces
    readonly property int startId: Math.max(1, activeId - count + 1)

    property real _bounceX: 0
    Behavior on _bounceX { Spring { epsilon: 0.05 } }
    Timer {
        id: bounceReset
        interval: 90
        repeat: false
        onTriggered: root._bounceX = 0
    }

    function go(id) {
        if (id < 1 && activeId <= 1) {
            _bounceX = -Theme.px(4);
            bounceReset.restart();
            return;
        }
        id = Math.max(1, Math.round(id));
        if (id !== activeId) {
            Hyprland.dispatch("workspace " + id);
        }
    }

    readonly property int activeIndex: Math.max(0, Math.min(count - 1, activeId - startId))
    readonly property real targetDropletX: activeIndex * (pillW + spacing)

    implicitWidth: count * pillW + Math.max(0, count - 1) * spacing + (activeW - pillW)
    implicitHeight: activeH
    transform: Translate { x: root._bounceX }

    Row {
        id: dotsRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing

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

                Rectangle {
                    id: pillRect
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.text
                    opacity: d.active ? 0.0 : (d.busy ? 0.45 : 0.24)
                    scale: ma.containsMouse && !d.active ? 1.18 : 1
                    Behavior on opacity { NumberAnimation { duration: 160 } }
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

    // Liquid sliding active droplet with travel stretch
    Item {
        id: droplet
        x: root.targetDropletX
        anchors.verticalCenter: parent.verticalCenter
        readonly property real travel: Math.abs(root.targetDropletX - x)
        width: root.activeW + Math.min(Theme.px(9), travel * 0.55)
        height: root.activeH - Math.min(Theme.px(2.5), travel * 0.14)

        Behavior on x { Spring { spring: 5.4; damping: 0.48; epsilon: 0.2 } }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + Theme.px(6)
            height: parent.height + Theme.px(6)
            radius: width / 2
            color: root.activeColor
            opacity: 0.14
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + Theme.px(3)
            height: parent.height + Theme.px(3)
            radius: width / 2
            color: root.activeColor
            opacity: 0.26
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.activeColor
        }
    }
}
