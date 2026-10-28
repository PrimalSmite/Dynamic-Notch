pragma Singleton
import Quickshell
import QtQuick

// Дизайн-токены острова. Меняй здесь — применяется везде.
Singleton {
    id: t

    // ── Масштаб всего интерфейса ──
    readonly property real s: 1.15
    function px(v) { return Math.round(v * s); }

    // ── Шрифты ──
    readonly property string fontFamily: "SF Pro Rounded"
    readonly property string monoFamily: "JetBrainsMono Nerd Font Mono"
    readonly property string iconFamily: "Material Symbols Rounded"
    readonly property string glyphFamily: "Hack Nerd Font Propo"

    // ── Размеры ──
    readonly property int compactH: px(38)      // высота свёрнутой «чёлки»
    readonly property int hoverGrowW: px(16)    // насколько расширяется чёлка при наведении
    readonly property int hoverGrowH: px(5)     // насколько удлиняется вниз при наведении
    readonly property int notchFillet: px(10)   // радиус вогнутых «ушек» у верхнего края
    readonly property int compactRadius: px(15)
    readonly property int expandedRadius: px(30)
    readonly property int osdW: px(290)
    readonly property int osdH: px(42)
    readonly property int notifW: px(380)
    readonly property int notifH: px(64)
    readonly property int stripH: px(94)        // двухрядная шапка раскрытого дашборда
    readonly property int pad: px(14)
    readonly property int minWorkspaces: 5

    // ── Типографика ──
    readonly property int fs: px(13)
    readonly property int fsSmall: px(11)
    readonly property int fsTitle: px(15)
    readonly property int iconSize: px(17)

    // ── Анимация (пружина в стиле iOS) ──
    readonly property real springK: 4.8
    readonly property real springDamp: 0.43
    readonly property int fadeIn: 220
    readonly property int fadeOut: 110
    readonly property int fadeDelay: 60
    readonly property int osdMs: 1450
    readonly property int layoutOsdMs: 850      // смена раскладки — быстрая плашка
    readonly property int notifMs: 4500

    // ── Цвета ──
    readonly property color bg: "#000000"
    readonly property color text: "#FFFFFF"
    readonly property color text2: Qt.rgba(1, 1, 1, 0.55)
    readonly property color text3: Qt.rgba(1, 1, 1, 0.28)
    readonly property color card: Qt.rgba(1, 1, 1, 0.08)
    readonly property color cardHover: Qt.rgba(1, 1, 1, 0.13)
    readonly property color track: Qt.rgba(1, 1, 1, 0.14)
    readonly property color divider: Qt.rgba(1, 1, 1, 0.12)
    readonly property color blue: "#0A84FF"
    readonly property color green: "#30D158"
    readonly property color orange: "#FF9F0A"
    readonly property color yellow: "#FFD60A"
    readonly property color red: "#FF453A"
    readonly property color pink: "#FF375F"
    readonly property color purple: "#BF5AF2"
    readonly property color accent: red
}
