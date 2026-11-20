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
    property var _capsValues: ({})

    readonly property string shortCode: {
        const l = layout.toLowerCase();
        if (l.startsWith("english")) return "EN";
        if (l.startsWith("russian")) return "RU";
        if (l.startsWith("ukrainian")) return "UA";
        if (l.startsWith("belarusian")) return "BY";
        if (l.startsWith("kazakh")) return "KZ";
        if (l.startsWith("german")) return "DE";
        if (l.startsWith("french")) return "FR";
        if (l.startsWith("spanish")) return "ES";
        if (l.startsWith("italian")) return "IT";
        if (l.startsWith("polish")) return "PL";
        if (l.startsWith("portuguese")) return "PT";
        if (l.startsWith("czech")) return "CZ";
        if (l.startsWith("turkish")) return "TR";
        if (l.startsWith("swedish")) return "SE";
        if (l.startsWith("finnish")) return "FI";
        if (l.startsWith("norwegian")) return "NO";
        if (l.startsWith("danish")) return "DK";
        if (l.startsWith("dutch")) return "NL";
        if (l.startsWith("japanese")) return "JA";
        if (l.startsWith("korean")) return "KO";
        if (l.startsWith("chinese")) return "ZH";
        if (l.startsWith("arabic")) return "AR";
        if (l.startsWith("hebrew")) return "HE";
        if (l.startsWith("greek")) return "EL";
        return layout.substring(0, 2).toUpperCase();
    }

    signal switched()

    function next() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    function _recalcCaps() {
        let lit = false;
        for (const k in _capsValues) {
            if (_capsValues[k] > 0) {
                lit = true;
                break;
            }
        }
        if (root.capsLock !== lit) root.capsLock = lit;
    }

    // Non-blocking FileView readers (never block UI thread)
    Instantiator {
        id: capsInst
        model: root._capsPaths
        delegate: FileView {
            required property string modelData
            path: modelData
            onLoaded: {
                root._capsValues[modelData] = parseInt(text().trim(), 10) || 0;
                root._recalcCaps();
            }
            onLoadFailed: {
                delete root._capsValues[modelData];
                root._recalcCaps();
                rescanTimer.restart();
            }
        }
    }

    function pollCaps() {
        const cnt = capsInst.count;
        for (let i = 0; i < cnt; i++) {
            const fv = capsInst.objectAt(i);
            if (fv) fv.reload();
        }
    }

    // 200ms async poll (down from 50ms synchronous blocking poll)
    Timer {
        interval: 200
        running: root._capsPaths.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pollCaps()
    }

    // Rescan keyboard LEDs on hotplug/failure
    Timer {
        id: rescanTimer
        interval: 1500
        repeat: false
        onTriggered: {
            if (!ledScanProc.running) ledScanProc.running = true;
        }
    }

    Process {
        id: ledScanProc
        running: true
        command: ["sh", "-c", "ls /sys/class/leds/*::capslock/brightness 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").map(s => s.trim()).filter(s => s.length > 0);
                root._capsValues = ({});
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
            if (ev.name === "configreloaded") {
                rescanTimer.restart();
                return;
            }
            if (ev.name !== "activelayout") return;
            const name = ev.data.substring(ev.data.indexOf(",") + 1);
            if (name === "error" || name === root.layout) return;
            root.layout = name;
            root.switched();
        }
    }
}
