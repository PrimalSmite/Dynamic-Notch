import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components

// Панель запуска приложений (поиск, закреплённые, частые).
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property bool wantsTextInput: true
    property string query: ""
    property int selectedIndex: 0

    implicitHeight: col.implicitHeight

    onVisibleChanged: {
        if (visible) {
            searchInput.text = "";
            selectedIndex = 0;
            searchInput.forceActiveFocus();
        }
    }

    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        const all = Apps.allEntries.slice();
        let res = [];
        if (q === "") {
            res = all;
            res.sort((a, b) => {
                const pa = Apps.isPinned(a.id) ? 1000 : 0;
                const pb = Apps.isPinned(b.id) ? 1000 : 0;
                const sa = Apps.score(a) + pa;
                const sb = Apps.score(b) + pb;
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
        return res.slice(0, 24);
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
        spacing: Theme.px(12)

        // Поле поиска
        Rectangle {
            width: parent.width
            height: Theme.px(42)
            radius: Theme.px(14)
            color: Theme.card

            Icon {
                id: sIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(14)
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: Theme.px(19)
                color: Theme.text2
            }

            TextInput {
                id: searchInput
                anchors.left: sIcon.right
                anchors.right: clearBtn.left
                anchors.leftMargin: Theme.px(10)
                anchors.rightMargin: Theme.px(10)
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(14)
                selectionColor: Theme.blue
                clip: true
                focus: true
                onTextChanged: {
                    root.query = text;
                    root.selectedIndex = 0;
                }
                Keys.onReturnPressed: root.launchSelected()
                Keys.onEnterPressed: root.launchSelected()
                Keys.onDownPressed: root.selectedIndex = Math.min(root.filtered.length - 1, root.selectedIndex + 4)
                Keys.onUpPressed: root.selectedIndex = Math.max(0, root.selectedIndex - 4)
                Keys.onRightPressed: if (cursorPosition === text.length) root.selectedIndex = Math.min(root.filtered.length - 1, root.selectedIndex + 1)
                Keys.onLeftPressed: if (cursorPosition === 0) root.selectedIndex = Math.max(0, root.selectedIndex - 1)

                Text {
                    visible: searchInput.text.length === 0
                    text: "Поиск приложений... (ПКМ — закрепить на панели)"
                    color: Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(13)
                }
            }

            Item {
                id: clearBtn
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(10)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(24); height: width
                visible: searchInput.text.length > 0
                Icon { anchors.centerIn: parent; name: "close"; size: Theme.px(16); color: Theme.text2 }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { searchInput.text = ""; searchInput.forceActiveFocus(); }
                }
            }
        }

        // Сетка приложений (4 колонки)
        GridView {
            id: grid
            width: parent.width
            height: Theme.px(292)
            cellWidth: Math.floor(width / 4)
            cellHeight: Theme.px(72)
            clip: true
            model: root.filtered

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight

                readonly property bool selected: index === root.selectedIndex
                readonly property bool pinned: Apps.isPinned(modelData.id)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.px(4)
                    radius: Theme.px(14)
                    color: cell.selected || cellMa.containsMouse ? Theme.cardHover : Theme.card
                    border.width: cell.selected ? 1.5 : 0
                    border.color: Theme.blue
                    scale: cellMa.pressed ? 0.95 : 1.0
                    Behavior on scale { Spring {} }
                    Behavior on color { ColorAnimation { duration: 130 } }

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.px(10)
                        spacing: Theme.px(10)

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: Theme.px(34)
                            source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.px(48)
                            spacing: Theme.px(2)

                            Row {
                                width: parent.width
                                spacing: Theme.px(4)
                                Text {
                                    width: parent.width - (cell.pinned ? Theme.px(14) : 0)
                                    elide: Text.ElideRight
                                    text: cell.modelData.name || cell.modelData.id
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.px(13)
                                    font.weight: Font.DemiBold
                                }
                                Icon {
                                    visible: cell.pinned
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "push_pin"
                                    size: Theme.px(12)
                                    color: Theme.accent
                                }
                            }

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: cell.modelData.genericName || cell.modelData.comment || "Приложение"
                                color: Theme.text2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                            }
                        }
                    }

                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = cell.index
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                Apps.togglePin(cell.modelData.id);
                            } else {
                                Apps.launch(cell.modelData);
                                if (root.host) root.host.collapse();
                            }
                        }
                    }
                }
            }
        }
    }
}
