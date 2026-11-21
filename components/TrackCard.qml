import QtQuick
import Quickshell.Widgets
import qs.services

Item {
    id: tc
    property string title: ""
    property string artist: ""
    property string art: ""
    property bool skeleton: false
    property real artScale: 1.0

    ClippingRectangle {
        id: tcArt
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(46)
        height: Theme.px(46)
        radius: Theme.px(11)
        color: Qt.rgba(1, 1, 1, 0.09)
        scale: tc.artScale

        Icon {
            anchors.centerIn: parent
            name: "music_note"
            size: Theme.px(20)
            color: Theme.text2
            visible: tc.skeleton || !tcArtImg.visible
        }
        Image {
            id: tcArtImg
            anchors.fill: parent
            source: tc.skeleton ? "" : tc.art
            cache: true
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(96, 96)
            visible: !tc.skeleton && status === Image.Ready && source !== ""
        }
    }

    Column {
        anchors.left: tcArt.right
        anchors.leftMargin: Theme.px(11)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(3)
        opacity: tc.skeleton ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: tc.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.px(13.5)
            font.weight: Font.DemiBold
        }
        Text {
            visible: tc.artist !== ""
            width: parent.width
            elide: Text.ElideRight
            text: tc.artist
            color: Theme.text2
            font.family: Theme.fontFamily
            font.pixelSize: Theme.px(11.5)
        }
    }

    // Skeleton placeholders while waiting for browser MPRIS metadata
    Column {
        anchors.left: tcArt.right
        anchors.leftMargin: Theme.px(11)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(6)
        visible: tc.skeleton

        Rectangle {
            width: Math.min(parent.width * 0.78, Theme.px(140))
            height: Theme.px(11)
            radius: Theme.px(5)
            color: Qt.rgba(1, 1, 1, 0.16)
        }
        Rectangle {
            width: Math.min(parent.width * 0.48, Theme.px(88))
            height: Theme.px(9)
            radius: Theme.px(4.5)
            color: Qt.rgba(1, 1, 1, 0.10)
        }
    }
}
