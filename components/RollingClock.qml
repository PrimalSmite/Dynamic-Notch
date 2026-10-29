import QtQuick
import qs.services

// Часы с посимвольной плавной iOS-анимацией перелистывания цифр при смене времени.
Row {
    id: root

    property string timeString: "00:00"
    property int fontSize: Theme.px(14)
    property int fontWeight: Font.DemiBold
    property color textColor: Theme.text
    property bool animated: true

    spacing: 0

    Repeater {
        model: root.timeString.length

        Item {
            id: slot
            required property int index
            readonly property string ch: root.timeString.charAt(index)
            readonly property bool isColon: ch === ":"

            width: isColon ? colonMetrics.advanceWidth : digitMetrics.advanceWidth
            height: digitMetrics.height
            clip: false

            property string currentCh: ch
            property string prevCh: ch

            onChChanged: {
                if (ch === currentCh) return;
                prevCh = currentCh;
                currentCh = ch;
                if (root.animated) {
                    rollAnim.restart();
                } else {
                    newTxt.y = 0;
                    newTxt.opacity = 1;
                    newTxt.scale = 1;
                    oldTxt.opacity = 0;
                }
            }

            // Уходящая цифра (плавно уходит вверх с лёгким уменьшением и размытием)
            Text {
                id: oldTxt
                anchors.horizontalCenter: parent.horizontalCenter
                text: slot.prevCh
                color: root.textColor
                font.family: Theme.fontFamily
                font.pixelSize: root.fontSize
                font.weight: root.fontWeight
                font.features: { "tnum": 1 }
                opacity: 0
                y: 0
                scale: 1
                visible: opacity > 0.01
            }

            // Новая (текущая) цифра (плавно всплывает снизу на пружине)
            Text {
                id: newTxt
                anchors.horizontalCenter: parent.horizontalCenter
                text: slot.currentCh
                color: root.textColor
                font.family: Theme.fontFamily
                font.pixelSize: root.fontSize
                font.weight: root.fontWeight
                font.features: { "tnum": 1 }
                opacity: 1
                y: 0
                scale: 1
            }

            ParallelAnimation {
                id: rollAnim

                // Старая цифра уезжает вверх и растворяется
                NumberAnimation {
                    target: oldTxt
                    property: "y"
                    from: 0
                    to: -slot.height * 0.55
                    duration: 280
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: oldTxt
                    property: "opacity"
                    from: 0.9
                    to: 0
                    duration: 240
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: oldTxt
                    property: "scale"
                    from: 1.0
                    to: 0.78
                    duration: 260
                    easing.type: Easing.OutCubic
                }

                // Новая цифра выезжает снизу с пружиной в стиле iOS
                SpringAnimation {
                    target: newTxt
                    property: "y"
                    from: slot.height * 0.6
                    to: 0
                    spring: Theme.springK
                    damping: Theme.springDamp
                    epsilon: 0.02
                }
                NumberAnimation {
                    target: newTxt
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 220
                    easing.type: Easing.OutCubic
                }
                SpringAnimation {
                    target: newTxt
                    property: "scale"
                    from: 0.8
                    to: 1.0
                    spring: Theme.springK
                    damping: Theme.springDamp
                    epsilon: 0.02
                }
            }
        }
    }

    TextMetrics {
        id: digitMetrics
        font.family: Theme.fontFamily
        font.pixelSize: root.fontSize
        font.weight: root.fontWeight
        text: "0"
    }

    TextMetrics {
        id: colonMetrics
        font.family: Theme.fontFamily
        font.pixelSize: root.fontSize
        font.weight: root.fontWeight
        text: ":"
    }
}
