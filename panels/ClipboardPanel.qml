import QtQuick
import Quickshell
import qs.services
import qs.components

// Clipboard history panel (cliphist + wl-copy) with text and image preview support.
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property bool wantsTextInput: true
    property string query: ""
    property int selectedIndex: 0

    implicitWidth: Theme.px(440)
    implicitHeight: col.implicitHeight

    readonly property var results: {
        var all = Clipboard.entries;
        var q = query.trim().toLowerCase();
        if (!q.length)
            return all;
        var out = [];
        for (var i = 0; i < all.length; i++) {
            if (all[i].lower.indexOf(q) !== -1)
                out.push(all[i]);
        }
        return out;
    }

    function focusInput() {
        searchInput.forceActiveFocus();
    }

    function copyItem(it) {
        if (!it) return;
        Clipboard.copy(it);
        if (host) host.collapse();
    }

    function deleteItem(it) {
        if (!it) return;
        Clipboard.remove(it);
    }

    function wipeAll() {
        Clipboard.wipe();
    }

    function moveSelection(delta) {
        if (results.length === 0)
            return;
        var idx = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
        selectedIndex = idx;
        list.positionViewAtIndex(idx, ListView.Contain);
    }

    onVisibleChanged: {
        Clipboard.surfaceOpen = visible;
        if (visible) {
            query = "";
            searchInput.text = "";
            selectedIndex = 0;
            list.positionViewAtBeginning();
            if (Clipboard.dirty)
                Clipboard.refresh();
            focusTimer.restart();
        }
    }

    Component.onCompleted: {
        Clipboard.surfaceOpen = true;
        if (Clipboard.dirty)
            Clipboard.refresh();
        focusTimer.restart();
    }

    Timer {
        id: focusTimer
        interval: 35
        onTriggered: searchInput.forceActiveFocus()
    }

    onResultsChanged: {
        if (selectedIndex >= results.length)
            selectedIndex = Math.max(0, results.length - 1);
        if (results.length > 0 && list)
            list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        // Top bar: search + clear
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
                    cursorDelegate: Caret {}
                    clip: true
                    focus: true
                    onTextChanged: {
                        root.query = text;
                        root.selectedIndex = 0;
                        list.positionViewAtBeginning();
                    }
                    Keys.onReturnPressed: if (root.results.length > 0) root.copyItem(root.results[root.selectedIndex])
                    Keys.onEnterPressed: if (root.results.length > 0) root.copyItem(root.results[root.selectedIndex])
                    Keys.onDownPressed: root.moveSelection(1)
                    Keys.onUpPressed: root.moveSelection(-1)

                    Text {
                        visible: searchInput.text.length === 0
                        text: "Search clipboard... (" + (root.results.length === Clipboard.count ? Clipboard.count : root.results.length + " / " + Clipboard.count) + " items)"
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
                        text: "Clear"
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

        // Empty state
        Rectangle {
            visible: root.results.length === 0
            width: parent.width
            height: Theme.px(100)
            radius: Theme.px(18)
            color: Theme.card
            Text {
                anchors.centerIn: parent
                text: Clipboard.count === 0 ? "Clipboard is empty" : "Nothing found"
                color: Theme.text2
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(13)
            }
        }

        // List
        ListView {
            id: list
            visible: root.results.length > 0
            width: parent.width
            height: Math.min(Theme.px(300), contentHeight)
            spacing: Theme.px(6)
            clip: true
            model: root.results

            delegate: Rectangle {
                id: cRow
                required property var modelData
                required property int index
                width: ListView.view.width
                height: cRow.modelData.isImage ? Theme.px(48) : Theme.px(42)
                radius: Theme.px(12)
                color: index === root.selectedIndex || rMa.containsMouse ? Theme.cardHover : Theme.card

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(12)
                    anchors.rightMargin: Theme.px(10)
                    spacing: Theme.px(10)

                    // Image preview or icon
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: cRow.modelData.isImage
                        width: visible ? Theme.px(48) : 0
                        height: Theme.px(32)
                        radius: Theme.px(6)
                        color: Theme.card
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: cRow.modelData.thumb ? "file://" + cRow.modelData.thumb : ""
                            sourceSize.width: 128
                            sourceSize.height: 128
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !cRow.modelData.isImage
                        name: "content_copy"
                        size: Theme.px(16)
                        color: Theme.text2
                    }

                    // Text / Description
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - (cRow.modelData.isImage ? Theme.px(48 + 10) : Theme.px(16 + 10)) - (sizeLabelText.visible ? sizeLabelText.implicitWidth + Theme.px(10) : 0) - Theme.px(30)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        text: cRow.modelData.isImage ? cRow.modelData.label : cRow.modelData.text
                        color: Theme.text
                        font.family: cRow.modelData.isImage ? Theme.fontFamily : Theme.monoFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: index === root.selectedIndex ? Font.DemiBold : Font.Normal
                    }

                    // Size for images
                    Text {
                        id: sizeLabelText
                        anchors.verticalCenter: parent.verticalCenter
                        visible: cRow.modelData.isImage && cRow.modelData.sizeLabel.length > 0
                        text: cRow.modelData.sizeLabel
                        color: Theme.text3
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.px(11)
                    }

                    // Delete button
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
