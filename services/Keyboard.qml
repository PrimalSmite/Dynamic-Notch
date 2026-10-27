pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Текущая раскладка клавиатуры в Hyprland.
Singleton {
    id: root

    property string layout: ""            // напр. "Russian", "English (US)"
    readonly property string short: {
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
