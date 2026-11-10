import QtQuick
import qs.services

// Smooth text input caret in iOS / macOS style (Insertion point).
// Features:
// - Rounded capsule / pill with Theme.px(2) thickness
// - Soft asymmetric fade in and fade out (InOutSine easing)
// - Instant reset to 100% visibility on typing and cursor movement
// - Automatic selectionColor inheritance (default iOS blue Theme.blue)
// - Animation disabled on focus loss for energy efficiency
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

        // Static phase (caret fully visible when typing pauses)
        PauseAnimation { duration: 600 }

        // Soft fade out in iOS/macOS style
        NumberAnimation {
            target: bar
            property: "opacity"
            to: 0.0
            duration: 350
            easing.type: Easing.InOutSine
        }

        // Short pause in hidden state
        PauseAnimation { duration: 70 }

        // Soft fade back in
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
