import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.components

// Панель выбора обоев (стрелки + Enter — выбрать, R — случайные).
Item {
    id: root
    property var host: null
    property bool wantsKeyboard: true
    property var walls: []
    property string currentWall: ""
    property int selectedIndex: 0

    implicitHeight: col.implicitHeight

    readonly property string wallDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    Keys.onPressed: event => {
        if (event.key === Qt.Key_R) { pickRandom(); event.accepted = true; }
        else if (event.key === Qt.Key_Left) { selectedIndex = Math.max(0, selectedIndex - 1); wGrid.positionViewAtIndex(selectedIndex, GridView.Contain); event.accepted = true; }
        else if (event.key === Qt.Key_Right) { selectedIndex = Math.min(walls.length - 1, selectedIndex + 1); wGrid.positionViewAtIndex(selectedIndex, GridView.Contain); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { selectedIndex = Math.max(0, selectedIndex - 4); wGrid.positionViewAtIndex(selectedIndex, GridView.Contain); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { selectedIndex = Math.min(walls.length - 1, selectedIndex + 4); wGrid.positionViewAtIndex(selectedIndex, GridView.Contain); event.accepted = true; }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (walls[selectedIndex]) applyWall(walls[selectedIndex]);
            event.accepted = true;
        }
    }

    function applyWall(path) {
        if (!path) return;
        currentWall = path;
        const cmd = "if command -v awww >/dev/null 2>&1; then awww img '" + path + "' --transition-type grow --transition-fps 60 --transition-duration 1.2; "
                  + "elif [ -x ~/.local/bin/awww ]; then ~/.local/bin/awww img '" + path + "' --transition-type grow --transition-fps 60 --transition-duration 1.2; "
                  + "elif command -v swww >/dev/null 2>&1; then swww img '" + path + "' --transition-type grow --transition-fps 60 --transition-duration 1.2; "
                  + "elif command -v hyprctl >/dev/null 2>&1; then hyprctl hyprpaper preload '" + path + "' >/dev/null 2>&1; hyprctl hyprpaper wallpaper '," + path + "' >/dev/null 2>&1; fi";
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function pickRandom() {
        if (walls.length === 0) return;
        const idx = Math.floor(Math.random() * walls.length);
        selectedIndex = idx;
        wGrid.positionViewAtIndex(idx, GridView.Contain);
        applyWall(walls[idx]);
    }

    Process {
        running: true
        command: ["sh", "-c", "find ~/Pictures/Wallpapers -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort | head -n 60"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.walls = text.trim().split("\n").filter(s => s.length > 0);
            }
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
                    text: "Обои · " + root.walls.length + " изображений"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.px(14)
                    font.weight: Font.Bold
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.px(30)
                width: rndRow.implicitWidth + Theme.px(20)
                radius: height / 2
                color: rndMa.containsMouse ? Theme.cardHover : Theme.card

                Row {
                    id: rndRow
                    anchors.centerIn: parent
                    spacing: Theme.px(6)
                    Icon { name: "shuffle"; size: Theme.px(14); anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Случайные [R]"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: rndMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pickRandom()
                }
            }
        }

        // Сетка превью обоев (4 в ряд)
        GridView {
            id: wGrid
            width: parent.width
            height: Theme.px(236)
            cellWidth: Math.floor(width / 4)
            cellHeight: Theme.px(118)
            clip: true
            model: root.walls

            delegate: Item {
                id: wCell
                required property string modelData
                required property int index
                width: wGrid.cellWidth
                height: wGrid.cellHeight

                readonly property bool active: root.currentWall === modelData
                readonly property bool selected: root.selectedIndex === index

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.px(5)
                    radius: Theme.px(14)
                    color: Theme.card
                    border.width: wCell.active || wCell.selected ? 2 : 0
                    border.color: wCell.active ? Theme.accent : Theme.blue
                    scale: wMa.pressed ? 0.94 : wMa.containsMouse ? 1.02 : 1.0
                    Behavior on scale { Spring {} }

                    Image {
                        anchors.fill: parent
                        source: "file://" + wCell.modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(280, 160)
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Theme.px(24)
                        color: Qt.rgba(0, 0, 0, 0.55)
                        visible: wMa.containsMouse || wCell.active

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
                        onClicked: root.applyWall(wCell.modelData)
                    }
                }
            }
        }
    }
}
