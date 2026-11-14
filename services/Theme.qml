pragma Singleton
import Quickshell
import QtQuick

// Island design tokens. Edit here — applies everywhere.
Singleton {
    id: t

    // ── Interface Scale ──
    readonly property real s: IslandPrefs.uiScale
    function px(v) { return Math.round(v * s); }

    // ── Fonts ──
    readonly property string fontFamily: IslandPrefs.fontFamily
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
    readonly property int fs: px(IslandPrefs.fontSize)
    readonly property int fsSmall: px(Math.max(9, IslandPrefs.fontSize - 2))
    readonly property int fsTitle: px(IslandPrefs.fontSize + 2)
    readonly property int iconSize: px(17)

    // ── Animation (iOS-style spring) ──
    readonly property real springK: 5.8
    readonly property real springDamp: 0.46
    readonly property int fadeIn: 180
    readonly property int fadeOut: 90
    readonly property int fadeDelay: 40
    readonly property int osdMs: 1300
    readonly property int layoutOsdMs: 900      // layout switch — fast badge
    readonly property int notifMs: 4000

    // ── Colors ──
    readonly property color bg: "#000000"
    readonly property color surface: Qt.rgba(1, 1, 1, 0.06)
    readonly property color text: "#FFFFFF"
    readonly property color text2: Qt.rgba(1, 1, 1, 0.65)
    readonly property color text3: Qt.rgba(1, 1, 1, 0.35)
    readonly property color card: Qt.rgba(1, 1, 1, 0.08)
    readonly property color cardHover: Qt.rgba(1, 1, 1, 0.13)
    readonly property color track: Qt.rgba(1, 1, 1, 0.14)
    readonly property color divider: Qt.rgba(1, 1, 1, 0.10)

    // ── Premium control base (neutral matte-white foundation) ──
    readonly property color controlFill: "#FFFFFF"
    readonly property color controlTrack: Qt.rgba(1, 1, 1, 0.14)
    readonly property color controlMuted: Qt.rgba(1, 1, 1, 0.25)

    // ── Semantic accents ──
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
    readonly property color teal: "#64D2FF"
    readonly property color mint: "#42D9A7"
    readonly property color accent: controlFill
}
