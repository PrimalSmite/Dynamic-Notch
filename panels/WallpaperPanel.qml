import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components

// Compact wallpaper selector panel (arrows + Enter — select, R — random, O — choose folder, F — file).
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property bool wantsTextInput: searchInput.activeFocus
    property int selectedIndex: 0

    property string query: ""
    readonly property var filteredWalls: {
        const list = Wallpapers.walls;
        if (!list || !list.length) return [];
        if (!query.trim().length) return list;
        const q = query.trim().toLowerCase();
        return list.filter(w => w.toLowerCase().indexOf(q) !== -1);
    }

    implicitWidth: Theme.px(500)
    implicitHeight: col.implicitHeight

    Component.onCompleted: {
        if (Wallpapers.allWalls.length === 0 && !Wallpapers.scanning)
            Wallpapers.refresh();
        syncSelection();
        searchInput.forceActiveFocus();
    }

    onFilteredWallsChanged: syncSelection()

    Connections {
        target: Wallpapers
        function onWallsChanged() { root.syncSelection(); }
        function onCurrentWallChanged() { root.syncSelection(); }
    }

    function syncSelection() {
        if (!filteredWalls || filteredWalls.length === 0) {
            selectedIndex = 0;
            return;
        }
        const idx = filteredWalls.indexOf(Wallpapers.currentWall);
        if (idx >= 0) {
            selectedIndex = idx;
            wList.positionViewAtIndex(idx, ListView.Center);
        } else if (selectedIndex >= filteredWalls.length) {
            selectedIndex = Math.max(0, filteredWalls.length - 1);
        }
    }

    function focusInput() {
        searchInput.forceActiveFocus();
    }

    Keys.onPressed: event => {
        const t = (event.text || "").toLowerCase();
        if (event.key === Qt.Key_R || t === "r" || t === "к") {
            const picked = Wallpapers.pickRandom();
            const idx = filteredWalls.indexOf(picked);
            if (idx >= 0) {
                selectedIndex = idx;
                wList.positionViewAtIndex(idx, ListView.Center);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_O || t === "o" || t === "щ") {
            Wallpapers.pickFolderDialog();
            event.accepted = true;
        } else if (event.key === Qt.Key_F || t === "f" || t === "а") {
            Wallpapers.pickFileDialog();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left && filteredWalls.length > 0) {
            selectedIndex = Math.max(0, selectedIndex - 1);
            wList.positionViewAtIndex(selectedIndex, ListView.Center);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right && filteredWalls.length > 0) {
            selectedIndex = Math.min(filteredWalls.length - 1, selectedIndex + 1);
            wList.positionViewAtIndex(selectedIndex, ListView.Center);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (filteredWalls[selectedIndex]) Wallpapers.apply(filteredWalls[selectedIndex]);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (searchInput.text.length > 0) {
                searchInput.text = "";
                event.accepted = true;
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(8)

        // ── Top Bar: Search Input on left, Index Counter on right ──
        Item {
            width: parent.width
            height: Theme.px(22)

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(6)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: Theme.px(14)
                    color: Theme.text3
                }

                TextInput {
                    id: searchInput
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(220)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                    color: Theme.text
                    selectionColor: Theme.controlFill
                    cursorDelegate: Caret {}
                    clip: true
                    onTextChanged: {
                        root.query = text;
                        root.selectedIndex = 0;
                    }

                    Text {
                        visible: searchInput.text.length === 0
                        text: "Search wallpapers..."
                        color: Theme.text3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(11)
                    }
                }
            }

            // Index counter (e.g. 2/19)
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.filteredWalls.length > 0 ? ((root.selectedIndex + 1) + "/" + root.filteredWalls.length) : "0/0"
                color: Theme.text3
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(10)
                font.features: { "tnum": 1 }
            }
        }

        // ── Horizontal Wallpaper Carousel Preview ──
        Item {
            width: parent.width
            height: Theme.px(98)

            ListView {
                id: wList
                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: Theme.px(10)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.filteredWalls

                delegate: Item {
                    id: wCard
                    required property string modelData
                    required property int index
                    width: Theme.px(138)
                    height: Theme.px(92)

                    readonly property bool active: Wallpapers.currentWall === modelData
                    readonly property bool selected: root.selectedIndex === index

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.px(14)
                        color: "#121716"
                        border.width: wCard.selected ? 2 : (wCard.active ? 1.5 : 1)
                        border.color: wCard.selected ? Theme.controlFill : (wCard.active ? Theme.text2 : Qt.rgba(1, 1, 1, 0.12))
                        scale: wMa.pressed ? 0.94 : (wMa.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { Spring { epsilon: 0.01 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        // Wallpaper preview image
                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: Theme.px(2.5)
                            radius: Theme.px(12)
                            color: "#080B0B"

                            Image {
                                anchors.fill: parent
                                source: Wallpapers.fileUrl(wCard.modelData)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(Theme.px(200), Theme.px(130))
                                cache: true
                            }

                            // Dark gradient overlay at bottom for title readability
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: Theme.px(26)
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.85) }
                                }
                            }

                            // Wallpaper file name
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Theme.px(3)
                                width: parent.width - Theme.px(8)
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                text: {
                                    const raw = wCard.modelData.split("/").pop() || "";
                                    return raw.replace(/\.[^/.]+$/, "");
                                }
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(9)
                                font.weight: Font.DemiBold
                            }

                            // Active wallpaper badge (Indicator dot in top right)
                            Rectangle {
                                visible: wCard.active
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Theme.px(5)
                                width: Theme.px(6)
                                height: width
                                radius: width / 2
                                color: Theme.controlFill
                            }
                        }

                        MouseArea {
                            id: wMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedIndex = wCard.index;
                                Wallpapers.apply(wCard.modelData);
                            }
                        }
                    }
                }
            }

            // Empty state placeholder
            Column {
                visible: root.filteredWalls.length === 0
                anchors.centerIn: parent
                spacing: Theme.px(4)
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: Wallpapers.scanning ? "hourglass_top" : "image_not_supported"
                    size: Theme.px(18)
                    color: Theme.text3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Wallpapers.scanning ? "Scanning wallpapers..." : "No matching wallpapers"
                    color: Theme.text3
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                }
            }
        }

        // ── Bottom Action Row: File [F], Folder [O], Random [R], Enter Hint ──
        Item {
            width: parent.width
            height: Theme.px(22)

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(6)

                Rectangle {
                    height: Theme.px(22)
                    width: fRow.implicitWidth + Theme.px(10)
                    radius: height / 2
                    color: fMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.06)
                    Row {
                        id: fRow
                        anchors.centerIn: parent
                        spacing: Theme.px(3)
                        Icon { name: "image"; size: Theme.px(11); color: Theme.text2 }
                        Text { text: "File [F]"; color: Theme.text2; font.pixelSize: Theme.px(9); font.weight: Font.Medium }
                    }
                    MouseArea {
                        id: fMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.pickFileDialog()
                    }
                }

                Rectangle {
                    height: Theme.px(22)
                    width: oRow.implicitWidth + Theme.px(10)
                    radius: height / 2
                    color: oMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.06)
                    Row {
                        id: oRow
                        anchors.centerIn: parent
                        spacing: Theme.px(3)
                        Icon { name: "folder_open"; size: Theme.px(11); color: Theme.text2 }
                        Text { text: "Folder [O]"; color: Theme.text2; font.pixelSize: Theme.px(9); font.weight: Font.Medium }
                    }
                    MouseArea {
                        id: oMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.pickFolderDialog()
                    }
                }

                Rectangle {
                    height: Theme.px(22)
                    width: rRow.implicitWidth + Theme.px(10)
                    radius: height / 2
                    color: rMa.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.06)
                    Row {
                        id: rRow
                        anchors.centerIn: parent
                        spacing: Theme.px(3)
                        Icon { name: "shuffle"; size: Theme.px(11); color: Theme.text2 }
                        Text { text: "Random [R]"; color: Theme.text2; font.pixelSize: Theme.px(9); font.weight: Font.Medium }
                    }
                    MouseArea {
                        id: rMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const picked = Wallpapers.pickRandom();
                            const idx = root.filteredWalls.indexOf(picked);
                            if (idx >= 0) {
                                root.selectedIndex = idx;
                                wList.positionViewAtIndex(idx, ListView.Center);
                            }
                        }
                    }
                }
            }

            // Keyboard navigation hint matching screenshot
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Enter to apply"
                color: Theme.text3
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(9)
            }
        }
    }
}
