pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Current keyboard layout and Caps Lock state in Hyprland.
Singleton {
    id: root

    property string layout: ""            // e.g. "Russian", "English (US)"
    property bool capsLock: false
    property string _capsPath: ""

    readonly property string shortCode: {
        const l = layout.toLowerCase();
        if (l.startsWith("english")) return "EN";
        if (l.startsWith("russian")) return "RU";
        if (l.startsWith("ukrainian")) return "UA";
        if (l.startsWith("german")) return "DE";
        return layout.substring(0, 2).toUpperCase();
    }

    signal switched()

    function next() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    FileView {
        id: capsFile
        path: root._capsPath
        blockLoading: true
    }

    function pollCaps() {
        if (_capsPath === "") return;
        capsFile.reload();
        root.capsLock = parseInt(capsFile.text().trim(), 10) > 0;
    }

    Timer {
        interval: 300
        running: root._capsPath !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pollCaps()
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/leds/*::capslock/brightness 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: root._capsPath = text.trim()
        }
    }

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards;
                    const kb = kbs.find(k => k.main) ?? kbs[0];
                    if (kb) root.layout = kb.active_keymap;
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "activelayout") return;
            const name = ev.data.substring(ev.data.indexOf(",") + 1);
            if (name === "error" || name === root.layout) return;
            root.layout = name;
            root.switched();
        }
    }
}
