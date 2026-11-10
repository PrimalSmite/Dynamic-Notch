import QtQuick
import qs.services

// Плавная каретка ввода текста в стиле iOS / macOS (Insertion point).
// Особенности:
// - Скруглённая палочка (capsule / pill) толщиной Theme.px(2)
// - Мягкое асимметричное затухание и появление (fade in/out по кривой InOutSine)
// - Мгновенный сброс в 100% видимость при наборе текста и перемещении курсора
// - Автоматическое наследование цвета selectionColor (по умолчанию iOS blue Theme.blue)
// - Отключение анимации при потере фокуса для энергоэффективности
Item {
    id: root

    readonly property var inputItem: parent
    property color color: (inputItem && inputItem.selectionColor) ? inputItem.selectionColor : Theme.blue

    width: Theme.px(2)
    height: (inputItem && inputItem.cursorRectangle && inputItem.cursorRectangle.height > 0)
            ? Math.max(Theme.px(14), inputItem.cursorRectangle.height)
            : Theme.px(16)

    visible: inputItem ? (inputItem.cursorVisible && inputItem.activeFocus) : false

    Rectangle {
        id: bar
        anchors.fill: parent
        radius: width / 2
        color: root.color
        opacity: 1.0
    }

    SequentialAnimation {
        id: blinkAnim
        running: root.visible
        loops: Animation.Infinite

        // Статичная фаза (каретка полностью видна при остановке ввода)
        PauseAnimation { duration: 600 }

        // Мягкое затухание в стиле iOS/macOS
        NumberAnimation {
            target: bar
            property: "opacity"
            to: 0.0
            duration: 350
            easing.type: Easing.InOutSine
        }

        // Короткая пауза в скрытом состоянии
        PauseAnimation { duration: 70 }

        // Мягкое появление обратно
        NumberAnimation {
            target: bar
            property: "opacity"
            to: 1.0
            duration: 220
            easing.type: Easing.InOutSine
        }
    }

    function resetBlink() {
        bar.opacity = 1.0;
        blinkAnim.restart();
    }

    Connections {
        target: root.inputItem
        ignoreUnknownSignals: true
        function onCursorPositionChanged() { root.resetBlink(); }
        function onActiveFocusChanged() {
            if (root.inputItem && root.inputItem.activeFocus) root.resetBlink();
        }
        function onCursorVisibleChanged() {
            if (root.inputItem && root.inputItem.cursorVisible) root.resetBlink();
        }
    }
}
