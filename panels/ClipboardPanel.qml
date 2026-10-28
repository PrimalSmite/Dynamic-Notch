import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// Панель истории буфера обмена (cliphist + wl-copy).
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property bool wantsTextInput: true
    property var items: []          // [{ raw: "123\ttext", id: "123", text: "text", isImg: false }]
    property string query: ""
    property int selectedIndex: 0

    implicitHeight: col.implicitHeight

    function reload() {
        listProc.running = false;
        listProc.running = true;
    }

    onVisibleChanged: {
        if (visible) {
            reload();
            searchInput.text = "";
            selectedIndex = 0;
            searchInput.forceActiveFocus();
        }
    }

    Process {
        id: listProc
        running: true
        command: ["sh", "-c", "cliphist list 2>/dev/null | head -n 60"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(s => s.length > 0);
                const parsed = [];
                for (const ln of lines) {
                    const tab = ln.indexOf("\t");
                    const id = tab >= 0 ? ln.slice(0, tab) : "";
                    const body = tab >= 0 ? ln.slice(tab + 1) : ln;
                    const isImg = body.indexOf("[[ binary data") === 0;
                    parsed.push({ raw: ln, id: id, text: body, isImg: isImg });
                }
                root.items = parsed;
            }
        }
    }

    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        if (!q) return items;
        return items.filter(it => it.text.toLowerCase().indexOf(q) >= 0);
    }

    function copyItem(it) {
        if (!it) return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", it.raw]);
        if (host) host.collapse();
    }

    function deleteItem(it) {
        if (!it) return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", it.raw]);
        items = items.filter(x => x.id !== it.id);
    }

    function wipeAll() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        items = [];
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        // Верхняя строка: поиск + очистить
        Row {
            width: parent.width
            spacing: Theme.px(10)

            Rectangle {
                width: parent.width - clrBtn.width - parent.spacing
                height: Theme.px(40)
                radius: Theme.px(14)
                color: Theme.card

                Icon {
                    id: sIc
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.px(14)
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: Theme.px(18)
                    color: Theme.text2
                }

                TextInput {
                    id: searchInput
                    anchors.left: sIc.right
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.px(10)
                    anchors.rightMargin: Theme.px(12)
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(13)
                    selectionColor: Theme.blue
                    clip: true
                    focus: true
                    onTextChanged: { root.query = text; root.selectedIndex = 0; }
                    Keys.onReturnPressed: if (root.filtered.length > 0) root.copyItem(root.filtered[root.selectedIndex])
                    Keys.onEnterPressed: if (root.filtered.length > 0) root.copyItem(root.filtered[root.selectedIndex])
                    Keys.onDownPressed: root.selectedIndex = Math.min(root.filtered.length - 1, root.selectedIndex + 1)
                    Keys.onUpPressed: root.selectedIndex = Math.max(0, root.selectedIndex - 1)

                    Text {
                        visible: searchInput.text.length === 0
                        text: "Поиск в буфере обмена... (" + root.items.length + " записей)"
                        color: Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(13)
                    }
                }
            }

            Rectangle {
                id: clrBtn
                width: Theme.px(120)
                height: Theme.px(40)
                radius: Theme.px(14)
                color: clrMa.containsMouse ? Theme.cardHover : Theme.card
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(6)
                    Icon { name: "delete_sweep"; size: Theme.px(17); color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Очистить"
                        color: Theme.text2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: clrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.wipeAll()
                }
            }
        }

        // Пустое состояние
        Rectangle {
            visible: root.filtered.length === 0
            width: parent.width
            height: Theme.px(100)
            radius: Theme.px(18)
            color: Theme.card
            Text {
                anchors.centerIn: parent
                text: "Буфер обмена пуст"
                color: Theme.text2
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(13)
            }
        }

        // Список
        ListView {
            visible: root.filtered.length > 0
            width: parent.width
            height: Math.min(Theme.px(280), contentHeight)
            spacing: Theme.px(6)
            clip: true
            model: root.filtered

            delegate: Rectangle {
                id: cRow
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Theme.px(42)
                radius: Theme.px(12)
                color: index === root.selectedIndex || rMa.containsMouse ? Theme.cardHover : Theme.card

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(14)
                    anchors.rightMargin: Theme.px(10)
                    spacing: Theme.px(10)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: cRow.modelData.isImg ? "image" : "content_copy"
                        size: Theme.px(16)
                        color: cRow.modelData.isImg ? Theme.purple : Theme.text2
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.px(64)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        text: cRow.modelData.text
                        color: Theme.text
                        font.family: cRow.modelData.isImg ? Theme.fontFamily : Theme.monoFamily
                        font.pixelSize: Theme.px(12)
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(24); height: width
                        Icon { anchors.centerIn: parent; name: "close"; size: Theme.px(15); color: Theme.text3 }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.deleteItem(cRow.modelData)
                        }
                    }
                }

                MouseArea {
                    id: rMa
                    anchors.fill: parent
                    anchors.rightMargin: Theme.px(36)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = cRow.index
                    onClicked: root.copyItem(cRow.modelData)
                }
            }
        }
    }
}
