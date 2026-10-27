import QtQuick
import Quickshell.Hyprland
import qs.services

// Точки рабочих столов: активный — вытянутая пилюля, занятые — ярче пустых.
Row {
    id: root

    property var monitor: null           // HyprlandMonitor
    property real dot: 5
    property real activeW: 14
    spacing: 4

    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property var wsList: Hyprland.workspaces.values
    readonly property var occupied: {
        const s = {};
        for (const w of wsList)
            if (w.id > 0 && (!w.toplevels || w.toplevels.values.length > 0)) s[w.id] = true;
        return s;
    }
    readonly property int count: {
        let m = Theme.minWorkspaces;
        for (const w of wsList) if (w.id > m && w.id <= 10) m = w.id;
        return Math.max(m, Math.min(activeId, 10));
    }

    function go(id) {
        id = Math.max(1, Math.min(count, id));
        if (id !== activeId) Hyprland.dispatch("workspace " + id);
    }

    Repeater {
        model: root.count

        Item {
            id: d
            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: wsId === root.activeId
            readonly property bool busy: root.occupied[wsId] === true

            anchors.verticalCenter: parent.verticalCenter
            width: active ? root.activeW : root.dot
            height: root.dot
            Behavior on width { Spring {} }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.text
                opacity: d.active ? 1 : d.busy ? 0.55 : 0.22
                scale: ma.containsMouse && !d.active ? 1.25 : 1
                Behavior on opacity { NumberAnimation { duration: 250 } }
                Behavior on scale { NumberAnimation { duration: 150 } }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.go(d.wsId)
            }
        }
    }
}
