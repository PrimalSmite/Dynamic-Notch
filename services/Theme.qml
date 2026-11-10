pragma Singleton
import Quickshell
import QtQuick

// Island design tokens. Edit here — applies everywhere.
Singleton {
    id: t

    // ── Interface Scale ──
    readonly property real s: 1.15
    function px(v) { return Math.round(v * s); }

    // ── Fonts ──
    readonly property string fontFamily: "SF Pro Rounded"
    readonly property string monoFamily: "JetBrainsMono Nerd Font Mono"
    readonly property string iconFamily: "Material Symbols Rounded"
    readonly property string glyphFamily: "Hack Nerd Font Propo"

    // ── Dimensions ──
    readonly property int compactH: px(38)      // height of collapsed "notch"
    readonly property int hoverGrowW: px(16)    // how much the notch expands horizontally on hover
    readonly property int hoverGrowH: px(5)     // how much it extends downward on hover
    readonly property int notchFillet: px(10)   // radius of concave "ears" at the top edge
    readonly property int compactRadius: px(15)
    readonly property int expandedRadius: px(30)
    readonly property int osdW: px(290)
    readonly property int osdH: px(42)
    readonly property int notifW: px(380)
    readonly property int notifH: px(64)
    readonly property int stripH: px(94)        // two-row header of expanded dashboard
    readonly property int pad: px(14)
    readonly property int minWorkspaces: 5

    // ── Typography ──
    readonly property int fs: px(13)
    readonly property int fsSmall: px(11)
    readonly property int fsTitle: px(15)
    readonly property int iconSize: px(17)

    // ── Animation (iOS-style spring) ──
    readonly property real springK: 4.8
    readonly property real springDamp: 0.43
    readonly property int fadeIn: 220
    readonly property int fadeOut: 110
    readonly property int fadeDelay: 60
    readonly property int osdMs: 1450
    readonly property int layoutOsdMs: 850      // layout switch — fast badge
    readonly property int notifMs: 4500

    // ── Colors ──
    readonly property color bg: "#000000"
    readonly property color text: "#FFFFFF"
    readonly property color text2: Qt.rgba(1, 1, 1, 0.55)
    readonly property color text3: Qt.rgba(1, 1, 1, 0.28)
    readonly property color card: Qt.rgba(1, 1, 1, 0.08)
    readonly property color cardHover: Qt.rgba(1, 1, 1, 0.13)
    readonly property color track: Qt.rgba(1, 1, 1, 0.12)
    readonly property color divider: Qt.rgba(1, 1, 1, 0.10)

    // ── Premium control base (neutral matte-white foundation) ──
    readonly property color controlFill: "#FFFFFF"
    readonly property color controlTrack: Qt.rgba(1, 1, 1, 0.12)
    readonly property color controlMuted: Qt.rgba(1, 1, 1, 0.25)

    // ── Semantic accents (strictly for states and alerts) ──
    readonly property color warn: "#FF9F0A"         // Attention / High temperature / High load
    readonly property color alert: "#FF453A"        // Error / Mute / Critical threshold
    readonly property color ok: "#30D158"           // Success / Normal state

    readonly property color blue: "#0A84FF"
    readonly property color green: "#30D158"
    readonly property color orange: "#FF9F0A"
    readonly property color yellow: "#FFD60A"
    readonly property color red: "#FF453A"
    readonly property color pink: "#FF375F"
    readonly property color purple: "#BF5AF2"
    readonly property color accent: red
}
