import QtQuick
import Quickshell
import qs.services
import qs.components

// Панель управления питанием (двойной клик или повторное нажатие клавиши для подтверждения).
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property string armedKey: ""

    implicitHeight: col.implicitHeight

    readonly property var actions: [
        { key: "lock", label: "Блокировка [L]", icon: "lock", color: Theme.blue, confirm: false, cmd: "hyprlock 2>/dev/null || loginctl lock-session" },
        { key: "suspend", label: "Сон [S]", icon: "bedtime", color: Theme.purple, confirm: true, cmd: "systemctl suspend" },
        { key: "logout", label: "Выйти [E]", icon: "logout", color: Theme.orange, confirm: true, cmd: "hyprctl dispatch exit" },
        { key: "reboot", label: "Рестарт [R]", icon: "restart_alt", color: Theme.yellow, confirm: true, cmd: "systemctl reboot" },
        { key: "poweroff", label: "Выкл [P]", icon: "power_settings_new", color: Theme.red, confirm: true, cmd: "systemctl poweroff" }
    ]

    Keys.onPressed: event => {
        if (event.key === Qt.Key_L) { trigger(actions[0]); event.accepted = true; }
        else if (event.key === Qt.Key_S) { trigger(actions[1]); event.accepted = true; }
        else if (event.key === Qt.Key_E) { trigger(actions[2]); event.accepted = true; }
        else if (event.key === Qt.Key_R) { trigger(actions[3]); event.accepted = true; }
        else if (event.key === Qt.Key_P) { trigger(actions[4]); event.accepted = true; }
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

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        Row {
            width: parent.width
            spacing: Theme.px(10)
            readonly property real btnW: (width - 4 * spacing) / 5

            Repeater {
                model: root.actions

                Rectangle {
                    id: pBtn
                    required property var modelData
                    readonly property bool isArmed: root.armedKey === modelData.key
                    width: parent.btnW
                    height: Theme.px(92)
                    radius: Theme.px(20)
                    color: isArmed ? modelData.color : (pMa.containsMouse ? Theme.cardHover : Theme.card)
                    scale: pMa.pressed ? 0.93 : 1.0
                    Behavior on scale { Spring {} }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.px(7)

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Theme.px(38); height: width; radius: width / 2
                            color: pBtn.isArmed ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                            Icon {
                                anchors.centerIn: parent
                                name: pBtn.modelData.icon
                                size: Theme.px(19)
                                color: pBtn.isArmed ? "white" : pBtn.modelData.color
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: pBtn.isArmed ? "Подтвердить?" : pBtn.modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: Font.Bold
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
