import QtQuick
import qs.services

// Кнопка-иконка верхней панели дашборда.
// active — подсветка активной вкладки, badge — точка уведомления, hint — клавиша быстрого доступа.
Item {
    id: root
    property string icon: ""
    property string glyph: ""
    property string label: ""
    property string hint: ""
    property bool active: false
    property bool badge: false
    property color tint: Theme.text
    property real size: Theme.iconSize
    signal clicked()
    signal rightClicked()

    implicitWidth: Theme.px(34)
    implicitHeight: Theme.px(30)

    readonly property bool hovered: ma.containsMouse

    scale: ma.pressed ? 0.90 : ma.containsMouse ? 1.05 : 1.0
    Behavior on scale { Spring { epsilon: 0.01 } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.px(9)
        color: root.active ? Qt.rgba(1, 1, 1, 0.16)
             : ma.containsMouse ? Qt.rgba(1, 1, 1, 0.09)
             : "transparent"
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.glyph !== "" ? root.glyph : root.icon
        font.family: root.glyph !== "" ? Theme.glyphFamily : Theme.iconFamily
        font.pixelSize: root.size
        color: root.active ? Theme.text : root.tint
        opacity: root.active || ma.containsMouse ? 1 : 0.76
        scale: ma.pressed ? 0.88 : ma.containsMouse ? 1.06 : 1.0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on scale { Spring { epsilon: 0.01 } }
    }

    Rectangle {
        visible: root.badge
        width: Theme.px(6)
        height: width
        radius: width / 2
        color: Theme.accent
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Theme.px(4)
        anchors.topMargin: Theme.px(4)
    }

    Rectangle {
        width: root.active ? Theme.px(12) : Theme.px(4)
        height: Theme.px(3)
        radius: height / 2
        color: Theme.accent
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(2)
        opacity: root.active ? 1 : 0
        Behavior on width { Spring { epsilon: 0.5 } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -Theme.px(2)
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.rightClicked();
            else root.clicked();
        }
    }
}
