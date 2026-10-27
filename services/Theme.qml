pragma Singleton
import Quickshell
import QtQuick

// Дизайн-токены острова. Меняй здесь — применяется везде.
Singleton {
    // ── Шрифты ──
    // Альтернативы, которые у тебя установлены: "Rubik", "Space Grotesk", "Inter Display", "SF Compact Rounded"
    readonly property string fontFamily: "SF Pro Rounded"
    readonly property string iconFamily: "Material Symbols Rounded"

    // ── Размеры ──
    readonly property int compactH: 38      // высота свёрнутой «чёлки» (от верхнего края экрана)
    readonly property int notchFillet: 10   // радиус вогнутых «ушек» у верхнего края
    readonly property int compactRadius: 15 // нижние углы в свёрнутом виде
    readonly property int expandedRadius: 34
    readonly property int osdW: 290
    readonly property int osdH: 42
    readonly property int expandedW: 460
    readonly property int pad: 16           // внутренний отступ раскрытого острова
    readonly property int minWorkspaces: 5  // сколько точек показывать минимум

    // ── Анимация (пружина в стиле iOS) ──
    // Параметры подобраны под SpringAnimation Qt: response ≈ 0.36 c, damping ratio ≈ 0.78
    readonly property real springK: 4.8
    readonly property real springDamp: 0.43
    readonly property int fadeIn: 220
    readonly property int fadeOut: 110
    readonly property int fadeDelay: 60
    readonly property int osdMs: 1500       // сколько висит плашка громкости / раскладки

    // ── Цвета ──
    readonly property color bg: "#000000"
    readonly property color text: "#FFFFFF"
    readonly property color text2: Qt.rgba(1, 1, 1, 0.55)
    readonly property color text3: Qt.rgba(1, 1, 1, 0.28)
    readonly property color card: Qt.rgba(1, 1, 1, 0.08)
    readonly property color track: Qt.rgba(1, 1, 1, 0.14)
    readonly property color blue: "#0A84FF"
    readonly property color green: "#30D158"
    readonly property color orange: "#FF9F0A"
    readonly property color red: "#FF453A"
    readonly property color pink: "#FF375F"
    readonly property color purple: "#BF5AF2"
}
