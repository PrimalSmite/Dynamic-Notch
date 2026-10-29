import QtQuick
import qs.services

// Иконка Material Symbols по имени лигатуры: Icon { name: "volume_up" }
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
