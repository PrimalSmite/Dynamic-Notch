import QtQuick
import qs.services

// Плитка статистики: иконка, подпись, значение и полоска.
Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property string value: ""
    property real level: 0
    property color tint: Theme.blue
    property bool interactive: false
    signal moved(real v)
    signal iconClicked()
    signal wheel(int delta)

    implicitHeight: 74
    radius: 18
    color: Theme.card

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => root.wheel(w.angleDelta.y)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Item {
            width: parent.width
            height: 20
            Icon {
                id: ic
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                size: 18
                color: root.tint
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.iconClicked()
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.value
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
        Text {
            text: root.label
            color: Theme.text2
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
        Bar {
            width: parent.width
            height: 5
            value: root.level
            tint: root.tint
            interactive: root.interactive
            onMoved: v => root.moved(v)
        }
    }
}
