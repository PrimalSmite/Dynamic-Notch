import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components

// Панель запуска приложений в стиле вертикального Notch-списка (как на референсе).
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property bool wantsTextInput: true
    property string query: ""
    property int selectedIndex: 0

    implicitWidth: Theme.px(390)
    implicitHeight: col.implicitHeight

    function focusInput() {
        searchInput.forceActiveFocus();
    }

    onVisibleChanged: {
        if (visible) {
            searchInput.text = "";
            selectedIndex = 0;
            list.positionViewAtBeginning();
            searchInput.forceActiveFocus();
            focusTimer.restart();
        }
    }

    Component.onCompleted: {
        searchInput.forceActiveFocus();
        focusTimer.restart();
    }

    Timer {
        id: focusTimer
        interval: 35
        onTriggered: searchInput.forceActiveFocus()
    }

    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        const all = Apps.allEntries.slice();
        let res = [];
        if (q === "") {
            res = all;
            res.sort((a, b) => {
                const sa = Apps.score(a);
                const sb = Apps.score(b);
                if (sb !== sa) return sb - sa;
                return (a.name || "").localeCompare(b.name || "");
            });
        } else {
            for (const e of all) {
                const name = (e.name || "").toLowerCase();
                const gen = (e.genericName || "").toLowerCase();
                const id = (e.id || "").toLowerCase();
                if (name.indexOf(q) >= 0 || gen.indexOf(q) >= 0 || id.indexOf(q) >= 0)
                    res.push(e);
            }
            res.sort((a, b) => {
                const na = (a.name || "").toLowerCase().startsWith(q) ? 1 : 0;
                const nb = (b.name || "").toLowerCase().startsWith(q) ? 1 : 0;
                if (nb !== na) return nb - na;
                return Apps.score(b) - Apps.score(a);
            });
        }
        return res.slice(0, 40);
    }

    function launchSelected() {
        if (filtered.length === 0) return;
        const idx = Math.max(0, Math.min(filtered.length - 1, selectedIndex));
        Apps.launch(filtered[idx]);
        if (host) host.collapse();
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(8)

        // Строка поиска сверху
        Item {
            width: parent.width
            height: Theme.px(36)

            Icon {
                id: sIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(6)
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: Theme.px(16)
                color: Theme.text2
            }

            TextInput {
                id: searchInput
                anchors.left: sIcon.right
                anchors.right: clearBtn.left
                anchors.leftMargin: Theme.px(10)
                anchors.rightMargin: Theme.px(8)
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(13)
                selectionColor: Theme.blue
                clip: true
                focus: true
                onTextChanged: {
                    root.query = text;
                    root.selectedIndex = 0;
                    list.positionViewAtBeginning();
                }
                Keys.onReturnPressed: root.launchSelected()
                Keys.onEnterPressed: root.launchSelected()
                Keys.onDownPressed: {
                    root.selectedIndex = Math.min(root.filtered.length - 1, root.selectedIndex + 1);
                    list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                }
                Keys.onUpPressed: {
                    root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                    list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                }
                Keys.onEscapePressed: event => {
                    if (root.host) root.host.collapse();
                    event.accepted = true;
                }

                Text {
                    visible: searchInput.text.length === 0
                    text: "Search..."
                    color: Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(13)
                }
            }

            Item {
                id: clearBtn
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(4)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(22); height: width
                visible: searchInput.text.length > 0
                Icon { anchors.centerIn: parent; name: "close"; size: Theme.px(15); color: Theme.text2 }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { searchInput.text = ""; searchInput.forceActiveFocus(); }
                }
            }
        }

        // Тонкий разделитель под строкой поиска
        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // Вертикальный список приложений (6 строк видно сразу)
        ListView {
            id: list
            width: parent.width
            height: Theme.px(312)
            spacing: Theme.px(2)
            clip: true
            model: root.filtered

            delegate: Rectangle {
                id: rowItem
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Theme.px(50)
                radius: Theme.px(11)

                readonly property bool selected: index === root.selectedIndex

                color: selected ? Qt.rgba(1, 1, 1, 0.11)
                     : rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06)
                     : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                // Вертикальная белая капсула слева у выбранного элемента
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.px(4)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(3)
                    height: rowItem.selected ? Theme.px(22) : Theme.px(6)
                    radius: width / 2
                    color: Theme.text
                    opacity: rowItem.selected ? 1 : 0
                    Behavior on height { Spring {} }
                    Behavior on opacity { NumberAnimation { duration: 130 } }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(14)
                    anchors.rightMargin: Theme.px(12)
                    spacing: Theme.px(12)

                    // Подложка под иконку приложения
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(34)
                        height: width
                        radius: Theme.px(9)
                        color: Qt.rgba(1, 1, 1, 0.06)

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: Theme.px(22)
                            source: Quickshell.iconPath(rowItem.modelData.icon, "application-x-executable")
                        }
                    }

                    // Название и описание
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.px(52)
                        spacing: Theme.px(1)

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: rowItem.modelData.name || rowItem.modelData.id
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: rowItem.modelData.genericName || rowItem.modelData.comment || rowItem.modelData.id
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = rowItem.index
                    onClicked: {
                        Apps.launch(rowItem.modelData);
                        if (root.host) root.host.collapse();
                    }
                }
            }
        }
    }
}
