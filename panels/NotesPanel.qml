import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// Quick notes panel (saved in ~/.local/state/dynamic-notch/notes/).
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property bool wantsTextInput: true
    property var notes: []              // [{ name: "note.md", title: "note", path: "..." }]
    property string currentTitle: "Note"
    property string currentPath: ""
    property bool _loadingContent: false

    implicitWidth: Theme.px(560)
    implicitHeight: row.implicitHeight

    function focusInput() {
        editor.forceActiveFocus();
    }

    readonly property string notesDir: Quickshell.env("HOME") + "/.local/state/dynamic-notch/notes"

    function refreshList() {
        listProc.running = false;
        listProc.running = true;
    }

    function openNote(n) {
        if (!n) return;
        currentTitle = n.title;
        currentPath = n.path;
        readProc.command = ["cat", n.path];
        readProc.running = true;
    }

    function createNote() {
        const name = "Note_" + Qt.formatDateTime(new Date(), "hhmmss");
        const path = notesDir + "/" + name + ".md";
        currentTitle = name;
        currentPath = path;
        editor.text = "";
        saveCurrent();
        refreshList();
        editor.forceActiveFocus();
    }

    function deleteCurrent() {
        if (!currentPath) return;
        Quickshell.execDetached(["rm", "-f", currentPath]);
        currentPath = "";
        editor.text = "";
        refreshList();
    }

    function saveCurrent() {
        if (!currentPath) return;
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "_", notesDir, editor.text, currentPath]);
    }

    Timer {
        id: saveDebounce
        interval: 400
        onTriggered: root.saveCurrent()
    }

    Process {
        id: listProc
        running: true
        command: [
            "sh", "-c",
            "mkdir -p ~/.local/state/dynamic-notch/notes && "
            + "ls -1t ~/.local/state/dynamic-notch/notes/*.md 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(s => s.length > 0);
                const arr = [];
                for (const p of lines) {
                    const base = p.split("/").pop();
                    const title = base.replace(/\.md$/, "");
                    arr.push({ name: base, title: title, path: p });
                }
                root.notes = arr;
                if (!root.currentPath && arr.length > 0)
                    root.openNote(arr[0]);
            }
        }
    }

    Process {
        id: readProc
        stdout: StdioCollector {
            onStreamFinished: {
                root._loadingContent = true;
                editor.text = text;
                root._loadingContent = false;
            }
        }
    }

    Row {
        id: row
        width: parent.width
        spacing: Theme.px(10)

        // Left column — notes list
        Rectangle {
            width: Theme.px(210)
            height: Theme.px(240)
            radius: Theme.px(18)
            color: Theme.card

            Column {
                anchors.fill: parent
                anchors.margins: Theme.px(10)
                spacing: Theme.px(8)

                // "+ New Note" button
                Rectangle {
                    width: parent.width
                    height: Theme.px(34)
                    radius: Theme.px(10)
                    color: newMa.containsMouse ? Theme.blue : Qt.rgba(1, 1, 1, 0.1)

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(6)
                        Icon { name: "add"; size: Theme.px(17); anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "New Note"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.DemiBold
                        }
                    }
                    MouseArea {
                        id: newMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.createNote()
                    }
                }

                ListView {
                    width: parent.width
                    height: parent.height - Theme.px(42)
                    spacing: Theme.px(4)
                    clip: true
                    model: root.notes

                    delegate: Rectangle {
                        id: nItem
                        required property var modelData
                        width: ListView.view.width
                        height: Theme.px(32)
                        radius: Theme.px(9)
                        readonly property bool active: root.currentPath === modelData.path
                        color: active ? Theme.cardHover : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(10)
                            anchors.rightMargin: Theme.px(8)
                            spacing: Theme.px(6)
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "description"
                                size: Theme.px(15)
                                color: nItem.active ? Theme.orange : Theme.text2
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Theme.px(24)
                                elide: Text.ElideRight
                                text: nItem.modelData.title
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(12)
                                font.weight: nItem.active ? Font.DemiBold : Font.Normal
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openNote(nItem.modelData)
                        }
                    }
                }
            }
        }

        // Right pane — note editor
        Rectangle {
            width: parent.width - Theme.px(220)
            height: Theme.px(240)
            radius: Theme.px(18)
            color: Theme.card

            Column {
                anchors.fill: parent
                anchors.margins: Theme.px(14)
                spacing: Theme.px(8)

                Item {
                    width: parent.width
                    height: Theme.px(24)

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.currentTitle || "Note"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(14)
                        font.weight: Font.Bold
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(10)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Autosaved"
                            color: Theme.text3
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(10)
                        }

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "delete"
                            size: Theme.px(17)
                            color: Theme.red
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -Theme.px(4)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.deleteCurrent()
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.divider }

                Flickable {
                    id: flick
                    width: parent.width
                    height: parent.height - Theme.px(38)
                    contentWidth: width
                    contentHeight: Math.max(height, editor.paintedHeight + Theme.px(20))
                    clip: true

                    TextEdit {
                        id: editor
                        width: flick.width
                        height: Math.max(flick.height, paintedHeight + Theme.px(20))
                        color: Theme.text
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.px(13)
                        selectionColor: Theme.blue
                        cursorDelegate: Caret {}
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            if (!root._loadingContent)
                                saveDebounce.restart();
                        }

                        Text {
                            visible: editor.text.length === 0
                            text: "Start typing a note..."
                            color: Theme.text3
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(13)
                        }
                    }
                }
            }
        }
    }
}
