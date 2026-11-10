import QtQuick
import Quickshell
import qs.services
import qs.components

// Polkit / sudo password prompt panel styled after macOS/iOS Notch.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property bool wantsTextInput: true

    implicitWidth: Theme.px(390)
    implicitHeight: col.implicitHeight

    readonly property color teal: "#76B7C7"

    function focusInput() {
        pwdInput.forceActiveFocus();
    }

    onVisibleChanged: {
        if (visible) {
            pwdInput.text = "";
            focusTimer.restart();
        }
    }

    Component.onCompleted: focusTimer.restart()

    Timer {
        id: focusTimer
        interval: 30
        onTriggered: pwdInput.forceActiveFocus()
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(12)

        // Header: blue lock icon circle + "Authentication required"
        Row {
            width: parent.width
            spacing: Theme.px(10)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(28)
                height: width
                radius: width / 2
                color: Theme.mint

                Icon {
                    anchors.centerIn: parent
                    name: "lock"
                    size: Theme.px(15)
                    color: "#081512"
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Authentication required"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(14)
                font.weight: Font.DemiBold
            }
        }

        // Request description and actionId block inside dark card
        Rectangle {
            width: parent.width
            height: msgCol.implicitHeight + Theme.px(22)
            radius: Theme.px(16)
            color: "#121716"
            border.width: 1
            border.color: "#1C2422"

            Column {
                id: msgCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Theme.px(14)
                spacing: Theme.px(4)

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: Auth.message !== "" ? Auth.message : "Authentication is needed to run `/usr/bin/true` as the super user"
                    color: "#F0F4F3"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(12)
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Auth.actionId !== "" ? Auth.actionId : "org.freedesktop.policykit.exec"
                    color: "#6D7774"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                }
            }
        }

        // Password field label (+ error message if present)
        Row {
            width: parent.width
            spacing: Theme.px(8)

            Text {
                text: Auth.promptText !== "" ? Auth.promptText : "Password"
                color: "#6D7774"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(11)
                font.weight: Font.Medium
            }

            Text {
                visible: Auth.errorText !== ""
                text: "· " + Auth.errorText
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(11)
                font.weight: Font.DemiBold
            }
        }

        // Password input capsule with mint lock icon on the left (Screenshot #4)
        Rectangle {
            width: parent.width
            height: Theme.px(42)
            radius: height / 2
            color: "#080B0B"
            border.width: 1
            border.color: pwdInput.activeFocus ? Theme.mint : "#1E2624"

            Rectangle {
                id: lockBadge
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(6)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(30)
                height: width
                radius: width / 2
                color: Theme.mint

                Icon {
                    anchors.centerIn: parent
                    name: "lock"
                    size: Theme.px(14)
                    color: "#081512"
                }
            }

            TextInput {
                id: pwdInput
                anchors.left: lockBadge.right
                anchors.right: parent.right
                anchors.leftMargin: Theme.px(10)
                anchors.rightMargin: Theme.px(14)
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(14)
                echoMode: (Auth.flow && Auth.flow.responseVisible) ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                selectionColor: Theme.mint
                cursorDelegate: Caret { color: Theme.mint }
                clip: true
                focus: true

                Keys.onReturnPressed: {
                    Auth.submit(pwdInput.text);
                    pwdInput.text = "";
                }
                Keys.onEnterPressed: {
                    Auth.submit(pwdInput.text);
                    pwdInput.text = "";
                }
                Keys.onEscapePressed: event => {
                    Auth.cancel();
                    if (root.host) root.host.collapse();
                    event.accepted = true;
                }
            }
        }

        // Cancel / Authenticate buttons on the right matching Screenshot #4
        Item {
            width: parent.width
            height: Theme.px(36)

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(8)

                // Cancel button: dark rounded pill
                Rectangle {
                    height: Theme.px(34)
                    width: cancelTxt.implicitWidth + Theme.px(26)
                    radius: height / 2
                    color: cancelMa.containsMouse ? "#202826" : "#131918"
                    scale: cancelMa.pressed ? 0.94 : 1.0
                    Behavior on scale { Spring { epsilon: 0.01 } }

                    Text {
                        id: cancelTxt
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: "#E2E8E6"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Auth.cancel();
                            if (root.host) root.host.collapse();
                        }
                    }
                }

                // Authenticate button: White rounded pill with dark text
                Rectangle {
                    height: Theme.px(34)
                    width: authTxt.implicitWidth + Theme.px(28)
                    radius: height / 2
                    color: authMa.containsMouse ? Qt.rgba(1, 1, 1, 0.88) : Theme.controlFill
                    scale: authMa.pressed ? 0.94 : 1.0
                    Behavior on scale { Spring { epsilon: 0.01 } }

                    Text {
                        id: authTxt
                        anchors.centerIn: parent
                        text: "Authenticate"
                        color: "#000000"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        id: authMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Auth.submit(pwdInput.text);
                            pwdInput.text = "";
                        }
                    }
                }
            }
        }
    }
}
