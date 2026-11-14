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
    property var _capsPaths: []

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

    Instantiator {
        id: capsInst
        model: root._capsPaths
        delegate: FileView {
            required property string modelData
            path: modelData
            blockLoading: true
        }
    }

    function pollCaps() {
        const cnt = capsInst.count;
        if (cnt <= 0) return;
        let lit = false;
        for (let i = 0; i < cnt; i++) {
            const fv = capsInst.objectAt(i);
            if (!fv) continue;
            fv.reload();
            if (parseInt(fv.text().trim(), 10) > 0) {
                lit = true;
                break;
            }
        }
        if (root.capsLock !== lit) root.capsLock = lit;
    }

    Timer {
        interval: 50
        running: root._capsPaths.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pollCaps()
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/leds/*::capslock/brightness 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").map(s => s.trim()).filter(s => s.length > 0);
                root._capsPaths = lines;
            }
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
