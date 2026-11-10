import QtQuick
import QtQuick.Effects
import qs.services

// Контейнер содержимого острова с переходом как в iOS:
// появление — короткая задержка, fade + пружинный scale + расфокус → резкость;
// исчезание — быстрый fade с размытием.
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

    // размытие включаем только во время перехода — в покое слой не нужен
    layer.enabled: opacity > 0.001 && opacity < 0.999
    layer.effect: MultiEffect {
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 8
        blur: 1 - v.opacity
    }
}
