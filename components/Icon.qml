import QtQuick
import qs.services

// Material Symbols icon by ligature name: Icon { name: "volume_up" }
Text {
    property string name: ""
    property real size: Theme.px(18)
    text: name
    color: Theme.text
    font.family: Theme.iconFamily
    font.pixelSize: size
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.QtRendering
}
