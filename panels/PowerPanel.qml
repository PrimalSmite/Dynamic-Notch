import QtQuick
import Quickshell
import qs.services
import qs.components

// Power management panel (double-click or press key again to confirm).
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property string armedKey: ""

    implicitWidth: Theme.px(390)
    implicitHeight: powerPill.height

    readonly property var actions: [
        { key: "lock", label: "Lock", hint: "L", icon: "lock", cmd: "hyprlock >/dev/null 2>&1 || loginctl lock-session >/dev/null 2>&1", confirm: false },
        { key: "suspend", label: "Suspend", hint: "S", icon: "bedtime", cmd: "systemctl suspend", confirm: true },
        { key: "logout", label: "Log Out", hint: "E", icon: "logout", cmd: "hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1 || hyprctl dispatch exit >/dev/null 2>&1 || loginctl terminate-session \"${XDG_SESSION_ID:-self}\" >/dev/null 2>&1 || loginctl terminate-user \"$USER\" >/dev/null 2>&1", confirm: true },
        { key: "reboot", label: "Reboot", hint: "R", icon: "refresh", cmd: "systemctl reboot", confirm: true },
        { key: "poweroff", label: "Power Off", hint: "P", icon: "power_settings_new", cmd: "systemctl poweroff", confirm: true }
    ]

    Keys.onPressed: event => {
        const t = (event.text || "").toLowerCase();
        if (event.key === Qt.Key_L || t === "l" || t === "д") { trigger(actions[0]); event.accepted = true; }
        else if (event.key === Qt.Key_S || t === "s" || t === "ы") { trigger(actions[1]); event.accepted = true; }
        else if (event.key === Qt.Key_E || t === "e" || t === "у") { trigger(actions[2]); event.accepted = true; }
        else if (event.key === Qt.Key_R || t === "r" || t === "к") { trigger(actions[3]); event.accepted = true; }
        else if (event.key === Qt.Key_P || t === "p" || t === "з") { trigger(actions[4]); event.accepted = true; }
    }

    Timer {
        id: disarmTimer
        interval: 2800
        onTriggered: root.armedKey = ""
    }

    function trigger(item) {
        if (item.confirm && armedKey !== item.key) {
            armedKey = item.key;
            disarmTimer.restart();
            return;
        }
        armedKey = "";
        if (host) host.collapse();
        Quickshell.execDetached(["sh", "-c", item.cmd]);
    }

    // Outer capsule matching screenshot #2: solid black/charcoal pill
    Rectangle {
        id: powerPill
        width: parent.width
        height: row.implicitHeight + Theme.px(12) * 2
        radius: Theme.px(24)
        color: "#080B0B"

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.px(8)
            readonly property real itemW: Theme.px(66)
            readonly property real itemH: Theme.px(76)

            Repeater {
                model: root.actions

                Rectangle {
                    id: pBtn
                    required property var modelData
                    readonly property bool isArmed: root.armedKey === modelData.key
                    readonly property bool isSelected: isArmed || pMa.containsMouse

                    width: row.itemW
                    height: row.itemH
                    radius: Theme.px(18)

                    // Selected item turns white Theme.controlFill with dark content, others are dark squircle #131818
                    color: isSelected ? Theme.controlFill : "#131818"
                    scale: pMa.pressed ? 0.93 : 1.0
                    Behavior on scale { Spring { epsilon: 0.01 } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.px(7)

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: pBtn.modelData.icon
                            size: Theme.px(20)
                            color: pBtn.isSelected ? "#000000" : "#E2E8E6"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: pBtn.isArmed ? "Confirm?" : pBtn.modelData.label
                            color: pBtn.isSelected ? "#000000" : "#D0D7D5"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: pBtn.isSelected ? Font.Bold : Font.Medium
                        }
                    }

                    MouseArea {
                        id: pMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.trigger(pBtn.modelData)
                    }
                }
            }
        }
    }
}
