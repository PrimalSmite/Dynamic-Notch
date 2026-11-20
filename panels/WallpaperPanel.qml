import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components

// Minimalist centered-focus wallpaper selector panel
// (Left/Right or wheel — browse, Enter — apply, Ctrl+R — random, Ctrl+O — folder, Ctrl+F — file).
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

    readonly property string selectedWallPath: (filteredWalls && filteredWalls.length > 0 && selectedIndex >= 0 && selectedIndex < filteredWalls.length)
                                               ? filteredWalls[selectedIndex]
                                               : ""

    readonly property string selectedFileName: {
        if (!selectedWallPath) return "";
        return selectedWallPath.split("/").pop() || "";
    }

    readonly property string currentFolderLabel: {
        if (Wallpapers.selectedFolder) {
            const parts = Wallpapers.selectedFolder.split("/").filter(s => s.length > 0);
            return parts.length > 0 ? parts[parts.length - 1] : Wallpapers.selectedFolder;
        }
        if (selectedWallPath) {
            const slash = selectedWallPath.lastIndexOf("/");
            if (slash > 0) {
                const dir = selectedWallPath.substring(0, slash);
                const base = dir.split("/").pop() || "";
                if (base) return base;
            }
        }
        return "all";
    }

    implicitWidth: Theme.px(680)
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
            wList.positionViewAtIndex(selectedIndex, ListView.Center);
        }
    }

    function focusInput() {
        searchInput.forceActiveFocus();
    }

    function cycleFolder() {
        const list = Wallpapers.folders;
        if (!list || list.length <= 1) {
            Wallpapers.pickFolderDialog();
            return;
        }
        let cur = 0;
        for (let i = 0; i < list.length; i++) {
            if (list[i].path === Wallpapers.selectedFolder) {
                cur = i;
                break;
            }
        }
        const next = (cur + 1) % list.length;
        Wallpapers.selectedFolder = list[next].path;
        root.selectedIndex = 0;
    }

    function handleKey(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const t = (event.text || "").toLowerCase();

        if (ctrl && (event.key === Qt.Key_R || t === "r" || t === "к")) {
            const picked = Wallpapers.pickRandom();
            const idx = filteredWalls.indexOf(picked);
            if (idx >= 0) selectedIndex = idx;
            event.accepted = true;
        } else if (ctrl && (event.key === Qt.Key_O || t === "o" || t === "щ")) {
            Wallpapers.pickFolderDialog();
            event.accepted = true;
        } else if (ctrl && (event.key === Qt.Key_F || t === "f" || t === "а")) {
            Wallpapers.pickFileDialog();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left && filteredWalls.length > 0) {
            selectedIndex = Math.max(0, selectedIndex - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right && filteredWalls.length > 0) {
            selectedIndex = Math.min(filteredWalls.length - 1, selectedIndex + 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (filteredWalls[selectedIndex]) Wallpapers.apply(filteredWalls[selectedIndex]);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (searchInput.text.length > 0) {
                searchInput.text = "";
                event.accepted = true;
            }
        }
    }

    Keys.onPressed: event => root.handleKey(event)

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(12)

        // ── Top Bar: Search Input on left, Folder label on right ──
        Item {
            width: parent.width
            height: Theme.px(24)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(8)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: Theme.px(14)
                    color: Theme.text3
                }

                TextInput {
                    id: searchInput
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(320)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(11)
                    color: Theme.text
                    selectionColor: Theme.controlFill
                    cursorDelegate: Caret {}
                    clip: true
                    Keys.onPressed: event => root.handleKey(event)
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

            // Current folder / category label
            Text {
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(4)
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentFolderLabel
                color: folderMa.containsMouse ? Theme.text2 : Theme.text3
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(10)
                Behavior on color { ColorAnimation { duration: 120 } }

                MouseArea {
                    id: folderMa
                    anchors.fill: parent
                    anchors.margins: -Theme.px(4)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cycleFolder()
                }
            }
        }

        // ── Centered Focus Carousel ──
        Item {
            width: parent.width
            height: Theme.px(124)

            ListView {
                id: wList
                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: Theme.px(8)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.filteredWalls
                currentIndex: root.selectedIndex

                readonly property real slotW: Theme.px(146)
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (width - slotW) / 2
                preferredHighlightEnd: (width + slotW) / 2
                highlightMoveDuration: 240
                highlightMoveVelocity: -1

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        if (root.filteredWalls.length === 0) return;
                        const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        if (delta < 0)
                            root.selectedIndex = Math.min(root.filteredWalls.length - 1, root.selectedIndex + 1);
                        else if (delta > 0)
                            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                        event.accepted = true;
                    }
                }

                delegate: Item {
                    id: wCard
                    required property string modelData
                    required property int index

                    width: wList.slotW
                    height: wList.height

                    // Normalized distance from viewport center (0 = centered, 1 = adjacent, 2 = outer)
                    readonly property real itemCenter: x + width / 2
                    readonly property real viewCenter: wList.contentX + wList.width / 2
                    readonly property real signedDist: (itemCenter - viewCenter) / (wList.slotW + wList.spacing)
                    readonly property real absDist: Math.abs(signedDist)

                    readonly property real cardScale: Math.max(0.58, 1.0 - Math.min(absDist, 1.0) * 0.28 - Math.max(0.0, absDist - 1.0) * 0.10)
                    readonly property real cardOpacity: Math.max(0.18, 1.0 - Math.min(absDist, 1.0) * 0.28 - Math.max(0.0, absDist - 1.0) * 0.32)
                    readonly property real xShift: {
                        if (absDist <= 1.0) return 0;
                        const sign = signedDist > 0 ? -1 : 1;
                        return sign * Math.min(absDist - 1.0, 1.5) * Theme.px(22);
                    }

                    z: 100 - Math.round(absDist * 20)

                    Rectangle {
                        id: cardFrame
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: wCard.xShift
                        width: Theme.px(176)
                        height: Theme.px(110)
                        radius: Theme.px(14)
                        color: "#0A0C0C"
                        scale: wCard.cardScale * (wMa.pressed ? 0.96 : 1.0)
                        opacity: wCard.cardOpacity
                        border.width: wCard.absDist < 0.35 ? 1.2 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.45)

                        Behavior on border.width { NumberAnimation { duration: 140 } }

                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: cardFrame.border.width > 0 ? 1.2 : 0
                            radius: Theme.px(13)
                            color: "#080A0A"

                            Image {
                                anchors.fill: parent
                                source: Wallpapers.fileUrl(wCard.modelData)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(Theme.px(280), Theme.px(175))
                                cache: false
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

            // Left edge fade-to-black vignette
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Theme.px(72)
                z: 200
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.bg }
                    GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.72) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Right edge fade-to-black vignette
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Theme.px(72)
                z: 200
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.65; color: Qt.rgba(0, 0, 0, 0.72) }
                    GradientStop { position: 1.0; color: Theme.bg }
                }
            }

            // Empty state placeholder
            Column {
                visible: root.filteredWalls.length === 0
                anchors.centerIn: parent
                z: 250
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

        // ── Bottom Bar: Full filename on left, Index counter on right ──
        Item {
            width: parent.width
            height: Theme.px(18)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(4)
                anchors.right: counterText.left
                anchors.rightMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                text: root.selectedFileName
                elide: Text.ElideMiddle
                color: Theme.text3
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(10)
            }

            Text {
                id: counterText
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(4)
                anchors.verticalCenter: parent.verticalCenter
                text: root.filteredWalls.length > 0 ? ((root.selectedIndex + 1) + "/" + root.filteredWalls.length) : "0/0"
                color: Theme.text3
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(10)
                font.features: { "tnum": 1 }
            }
        }
    }
}
