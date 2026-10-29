import QtQuick
import Quickshell
import qs.services
import qs.components

// Панель ввода пароля Polkit / sudo в стиле macOS/iOS Notch (по референсу со скриншота).
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

        // Шапка: голубой кружок с замком + "Authentication required"
        Row {
            width: parent.width
            spacing: Theme.px(10)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(28)
                height: width
                radius: width / 2
                color: root.teal

                Icon {
                    anchors.centerIn: parent
                    name: "lock"
                    size: Theme.px(15)
                    color: "#0B161A"
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

        // Блок описания запроса и actionId
        Rectangle {
            width: parent.width
            height: msgCol.implicitHeight + Theme.px(20)
            radius: Theme.px(14)
            color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

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
                    text: Auth.message
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(12)
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Auth.actionId
                    color: Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                }
            }
        }

        // Подпись поля пароля (+ сообщение об ошибке, если есть)
        Row {
            width: parent.width
            spacing: Theme.px(8)

            Text {
                text: Auth.promptText
                color: Theme.text2
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

        // Капсула ввода пароля с голубой иконкой замка слева
        Rectangle {
            width: parent.width
            height: Theme.px(40)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.03)
            border.width: 1
            border.color: pwdInput.activeFocus ? Qt.rgba(0.46, 0.72, 0.78, 0.55) : Qt.rgba(1, 1, 1, 0.14)

            Rectangle {
                id: lockBadge
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(6)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(28)
                height: width
                radius: width / 2
                color: root.teal

                Icon {
                    anchors.centerIn: parent
                    name: "lock"
                    size: Theme.px(14)
                    color: "#0B161A"
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
                selectionColor: root.teal
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

        // Кнопки Cancel / Authenticate справа
        Item {
            width: parent.width
            height: Theme.px(32)

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(8)

                // Cancel
                Rectangle {
                    height: Theme.px(32)
                    width: cancelTxt.implicitWidth + Theme.px(26)
                    radius: height / 2
                    color: cancelMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                    scale: cancelMa.pressed ? 0.94 : 1.0
                    Behavior on scale { Spring { epsilon: 0.01 } }

                    Text {
                        id: cancelTxt
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.text
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

                // Authenticate
                Rectangle {
                    height: Theme.px(32)
                    width: authTxt.implicitWidth + Theme.px(28)
                    radius: height / 2
                    color: authMa.containsMouse ? Qt.lighter(root.teal, 1.08) : root.teal
                    scale: authMa.pressed ? 0.94 : 1.0
                    Behavior on scale { Spring { epsilon: 0.01 } }

                    Text {
                        id: authTxt
                        anchors.centerIn: parent
                        text: "Authenticate"
                        color: "#0B161A"
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
