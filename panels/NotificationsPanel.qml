import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components

// Notification center panel (D — do not disturb, C — clear all).
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    focus: true
    implicitWidth: Theme.px(430)
    implicitHeight: col.implicitHeight

    function focusInput() { root.forceActiveFocus(); }

    Keys.onPressed: event => {
        const ch = (event.text || "").toLowerCase();
        if (event.key === Qt.Key_D || event.key === 0x06d7 || ch === "d" || ch === "в") {
            Notifs.dnd = !Notifs.dnd;
            event.accepted = true;
        } else if (event.key === Qt.Key_C || event.key === Qt.Key_X || event.key === Qt.Key_Delete
                   || event.key === 0x06d3 || event.key === 0x06de
                   || ch === "c" || ch === "с" || ch === "x" || ch === "ч") {
            Notifs.clear();
            event.accepted = true;
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        // Header
        Item {
            width: parent.width
            height: Theme.px(36)

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(10)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(16)
                    font.weight: Font.Bold
                }

                // "Do Not Disturb" toggle
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: Theme.px(28)
                    width: dndRow.implicitWidth + Theme.px(20)
                    radius: height / 2
                    color: Notifs.dnd ? Theme.purple : Theme.card
                    scale: dndMa.pressed ? 0.93 : (dndMa.containsMouse ? 1.03 : 1.0)
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on scale { Spring { epsilon: 0.01 } }

                    Row {
                        id: dndRow
                        anchors.centerIn: parent
                        spacing: Theme.px(6)
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Notifs.dnd ? "do_not_disturb_on" : "notifications_active"
                            size: Theme.px(14)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Notifs.dnd ? "Do Not Disturb [D]" : "Sound On [D]"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        id: dndMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                }
            }

            // Clear all
            Rectangle {
                visible: Notifs.list.length > 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.px(28)
                width: clrText.implicitWidth + Theme.px(22)
                radius: height / 2
                color: clrMa.containsMouse ? Theme.cardHover : Theme.card
                scale: clrMa.pressed ? 0.93 : (clrMa.containsMouse ? 1.03 : 1.0)
                Behavior on scale { Spring { epsilon: 0.01 } }

                Text {
                    id: clrText
                    anchors.centerIn: parent
                    text: "Clear All [C]"
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: clrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.clear()
                }
            }
        }

        // Empty state
        Rectangle {
            visible: Notifs.list.length === 0
            width: parent.width
            height: Theme.px(120)
            radius: Theme.px(20)
            color: Theme.card

            Column {
                anchors.centerIn: parent
                spacing: Theme.px(6)
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: Notifs.dnd ? "do_not_disturb_on" : "notifications_none"
                    size: Theme.px(28)
                    color: Theme.text3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No new notifications"
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(13)
                }
            }
        }

        // Notifications list
        ListView {
            visible: Notifs.list.length > 0
            width: parent.width
            height: Math.min(Theme.px(320), contentHeight)
            spacing: Theme.px(8)
            clip: true
            model: Notifs.list

            delegate: Rectangle {
                id: card
                required property var modelData
                width: ListView.view.width
                height: Theme.px(68)
                radius: Theme.px(16)
                color: cardMa.containsMouse ? Theme.cardHover : Theme.card
                scale: cardMa.pressed ? 0.97 : 1.0
                Behavior on scale { Spring { epsilon: 0.01 } }
                opacity: card.modelData.read ? 0.6 : 1.0
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.px(12)
                    spacing: Theme.px(12)

                    ClippingRectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(40); height: width
                        radius: Theme.px(10)
                        color: Qt.rgba(1, 1, 1, 0.08)
                        Icon { anchors.centerIn: parent; name: "notifications"; size: Theme.px(20) }
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(Theme.px(80), Theme.px(80))
                            source: {
                                const n = card.modelData;
                                if (n.image) return n.image;
                                if (n.appIcon) return n.appIcon.indexOf("/") >= 0 ? n.appIcon : Quickshell.iconPath(n.appIcon, true);
                                return "";
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.px(92)
                        spacing: Theme.px(2)

                        Row {
                            width: parent.width
                            spacing: Theme.px(8)
                            Text {
                                width: parent.width - Theme.px(70) - (card.modelData.read ? 0 : Theme.px(12))
                                elide: Text.ElideRight
                                text: card.modelData.summary
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(13)
                                font.weight: card.modelData.read ? Font.Normal : Font.DemiBold
                            }
                            Rectangle {
                                visible: !card.modelData.read
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.px(6); height: width; radius: width / 2
                                color: Theme.accent
                            }
                            Text {
                                text: Notifs.timeAgo(card.modelData.time)
                                color: Theme.text3
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                            }
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            text: (card.modelData.body || card.modelData.appName).replace(/<[^>]*>/g, "")
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                        }
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(26); height: width
                        Icon { anchors.centerIn: parent; name: "close"; size: Theme.px(16); color: Theme.text2 }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.dismiss(card.modelData)
                        }
                    }
                }

                MouseArea {
                    id: cardMa
                    anchors.fill: parent
                    anchors.rightMargin: Theme.px(40)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.invoke(card.modelData, "default")
                }
            }
        }
    }
}
