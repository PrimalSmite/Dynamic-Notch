import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components

// Панель выбора обоев (стрелки + Enter — выбрать, R — случайные, O — выбрать папку, F — файл).
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property int selectedIndex: 0

    readonly property var walls: Wallpapers.walls
    implicitWidth: Theme.px(640)
    implicitHeight: col.implicitHeight

    Component.onCompleted: {
        if (Wallpapers.allWalls.length === 0 && !Wallpapers.scanning)
            Wallpapers.refresh();
        syncSelection();
    }

    onWallsChanged: syncSelection()

    function syncSelection() {
        const idx = walls.indexOf(Wallpapers.currentWall);
        if (idx >= 0) {
            selectedIndex = idx;
            wGrid.positionViewAtIndex(idx, GridView.Contain);
        } else if (selectedIndex >= walls.length) {
            selectedIndex = Math.max(0, walls.length - 1);
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_R) {
            const picked = Wallpapers.pickRandom();
            const idx = walls.indexOf(picked);
            if (idx >= 0) {
                selectedIndex = idx;
                wGrid.positionViewAtIndex(idx, GridView.Contain);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_O) {
            Wallpapers.pickFolderDialog();
            event.accepted = true;
        } else if (event.key === Qt.Key_F) {
            Wallpapers.pickFileDialog();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left && walls.length > 0) {
            selectedIndex = Math.max(0, selectedIndex - 1);
            wGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right && walls.length > 0) {
            selectedIndex = Math.min(walls.length - 1, selectedIndex + 1);
            wGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up && walls.length > 0) {
            selectedIndex = Math.max(0, selectedIndex - 4);
            wGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down && walls.length > 0) {
            selectedIndex = Math.min(walls.length - 1, selectedIndex + 4);
            wGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (walls[selectedIndex]) Wallpapers.apply(walls[selectedIndex]);
            event.accepted = true;
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.px(10)

        // Шапка
        Item {
            width: parent.width
            height: Theme.px(32)

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(8)
                Icon { name: "wallpaper"; size: Theme.px(17); color: Theme.pink; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Обои · " + root.walls.length
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(14)
                    font.weight: Font.Bold
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(6)

                // Кнопка выбора файла
                Rectangle {
                    height: Theme.px(28)
                    width: fileRow.implicitWidth + Theme.px(16)
                    radius: height / 2
                    color: fileMa.containsMouse ? Theme.cardHover : Theme.card

                    Row {
                        id: fileRow
                        anchors.centerIn: parent
                        spacing: Theme.px(5)
                        Icon { name: "image"; size: Theme.px(14); anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Файл [F]"
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: Font.DemiBold
                        }
                    }
                    MouseArea {
                        id: fileMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.pickFileDialog()
                    }
                }

                // Кнопка выбора папки
                Rectangle {
                    height: Theme.px(28)
                    width: dirRow.implicitWidth + Theme.px(16)
                    radius: height / 2
                    color: dirMa.containsMouse ? Theme.cardHover : Theme.card

                    Row {
                        id: dirRow
                        anchors.centerIn: parent
                        spacing: Theme.px(5)
                        Icon { name: "folder_open"; size: Theme.px(14); anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Папка [O]"
                            color: Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: Font.DemiBold
                        }
                    }
                    MouseArea {
                        id: dirMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.pickFolderDialog()
                    }
                }

                // Случайные обои
                Rectangle {
                    height: Theme.px(28)
                    width: rndRow.implicitWidth + Theme.px(16)
                    radius: height / 2
                    color: rndMa.containsMouse ? Theme.cardHover : Theme.card

                    Row {
                        id: rndRow
                        anchors.centerIn: parent
                        spacing: Theme.px(5)
                        Icon { name: "shuffle"; size: Theme.px(14); anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Случайные [R]"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: Font.DemiBold
                        }
                    }
                    MouseArea {
                        id: rndMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const picked = Wallpapers.pickRandom();
                            const idx = root.walls.indexOf(picked);
                            if (idx >= 0) {
                                root.selectedIndex = idx;
                                wGrid.positionViewAtIndex(idx, GridView.Contain);
                            }
                        }
                    }
                }
            }
        }

        // Фильтр по папкам (если найдено больше одной папки)
        Flickable {
            visible: Wallpapers.folders.length > 2
            width: parent.width
            height: Theme.px(26)
            contentWidth: folderRow.implicitWidth
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: folderRow
                height: parent.height
                spacing: Theme.px(6)

                Repeater {
                    model: Wallpapers.folders

                    Rectangle {
                        id: fChip
                        required property var modelData
                        readonly property bool active: Wallpapers.selectedFolder === modelData.path
                        height: Theme.px(26)
                        width: fTxt.implicitWidth + Theme.px(18)
                        radius: height / 2
                        color: active ? Theme.blue : (fMa.containsMouse ? Theme.cardHover : Theme.card)

                        Text {
                            id: fTxt
                            anchors.centerIn: parent
                            text: fChip.modelData.name + " (" + fChip.modelData.count + ")"
                            color: fChip.active ? "white" : Theme.text2
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.px(11)
                            font.weight: fChip.active ? Font.Bold : Font.Medium
                        }

                        MouseArea {
                            id: fMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Wallpapers.selectedFolder = fChip.modelData.path;
                                root.selectedIndex = 0;
                                wGrid.positionViewAtBeginning();
                            }
                        }
                    }
                }
            }
        }

        // Сетка превью обоев (4 в ряд)
        Item {
            width: parent.width
            height: Theme.px(240)

            GridView {
                id: wGrid
                anchors.fill: parent
                visible: root.walls.length > 0
                cellWidth: Math.floor(width / 4)
                cellHeight: Theme.px(120)
                clip: true
                cacheBuffer: Theme.px(60)
                model: root.walls

                delegate: Item {
                    id: wCell
                    required property string modelData
                    required property int index
                    width: wGrid.cellWidth
                    height: wGrid.cellHeight

                    readonly property bool active: Wallpapers.currentWall === modelData
                    readonly property bool selected: root.selectedIndex === index

                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.px(4)
                        radius: Theme.px(14)
                        color: Theme.card
                        border.width: wCell.active ? 2.5 : (wCell.selected ? 2 : 0)
                        border.color: wCell.active ? Theme.green : Theme.blue
                        scale: wMa.pressed ? 0.94 : wMa.containsMouse ? 1.02 : 1.0
                        Behavior on scale { Spring { epsilon: 0.01 } }

                        Image {
                            id: thumbImg
                            anchors.fill: parent
                            source: Wallpapers.fileUrl(wCell.modelData)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(Math.round(wGrid.cellWidth * 1.2), Math.round(wGrid.cellHeight * 1.2))
                            cache: true
                        }

                        // Бейдж активных обоев
                        Rectangle {
                            visible: wCell.active
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: Theme.px(6)
                            width: Theme.px(20)
                            height: width
                            radius: width / 2
                            color: Theme.green

                            Icon {
                                anchors.centerIn: parent
                                name: "check"
                                size: Theme.px(13)
                                color: "#000000"
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: Theme.px(24)
                            color: Qt.rgba(0, 0, 0, 0.62)
                            visible: wMa.containsMouse || wCell.active || wCell.selected

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - Theme.px(12)
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                text: wCell.modelData.split("/").pop()
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.px(10)
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            id: wMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedIndex = wCell.index;
                                Wallpapers.apply(wCell.modelData);
                            }
                        }
                    }
                }
            }

            // Заглушка если обои ещё не найдены
            Column {
                visible: root.walls.length === 0
                anchors.centerIn: parent
                spacing: Theme.px(8)

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: Wallpapers.scanning ? "hourglass_top" : "folder_open"
                    size: Theme.px(28)
                    color: Theme.text3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Wallpapers.scanning ? "Поиск обоев…" : "Обои не найдены. Нажмите «Папка [O]» или «Файл [F]»"
                    color: Theme.text2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(12)
                }
            }
        }
    }
}

