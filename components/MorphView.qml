import QtQuick
import qs.services

// Island content container with iOS-style transition:
// entrance — short delay, fade + spring scale + slide;
// exit — fast fade without GPU-heavy offscreen blur shader passes.
Item {
    id: v
    property bool shown: false
    property real hiddenScale: 0.86
    property real hiddenY: -Theme.px(10)
    property real offsetY: shown ? 0 : hiddenY

    enabled: shown
    visible: shown || opacity > 0.001
    opacity: shown ? 1 : 0
    scale: shown ? 1 : hiddenScale
    transform: Translate { y: v.offsetY }

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: v.shown ? Theme.fadeDelay : 0 }
            NumberAnimation {
                duration: v.shown ? Theme.fadeIn : Theme.fadeOut
                easing.type: v.shown ? Easing.OutCubic : Easing.InQuad
            }
        }
    }
    Behavior on scale { Spring { epsilon: 0.01 } }
    Behavior on offsetY { Spring { epsilon: 0.05 } }
}
