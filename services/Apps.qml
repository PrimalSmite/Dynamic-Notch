pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Application service: pinned icons and launch history for ranking.
Singleton {
    id: root

    readonly property string pinsPath: Quickshell.env("HOME") + "/.config/dynamic-notch/pins.json"
    readonly property string usagePath: Quickshell.env("HOME") + "/.local/state/dynamic-notch/launcher-usage.json"

    property var pinIds: ["firefox", "steam", "org.telegram.desktop", "discord"]
    property var usage: ({})

    readonly property var allEntries: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    readonly property var pins: {
        const res = [];
        const _ = allEntries.length; // dependency on list updates
        for (const id of pinIds) {
            const e = findById(id);
            if (e) res.push(e);
        }
        return res;
    }

    function findById(id) {
        if (!id) return null;
        let e = DesktopEntries.byId(id);
        if (e) return e;
        e = DesktopEntries.heuristicLookup(id);
        if (e) return e;
        const low = id.toLowerCase();
        for (const item of allEntries) {
            if ((item.id && item.id.toLowerCase().indexOf(low) >= 0) ||
                (item.name && item.name.toLowerCase().indexOf(low) >= 0))
                return item;
        }
        return null;
    }

    function isPinned(id) {
        return pinIds.indexOf(id) >= 0;
    }

    function togglePin(id) {
        if (!id) return;
        const next = pinIds.slice();
        const idx = next.indexOf(id);
        if (idx >= 0) next.splice(idx, 1);
        else next.push(id);
        pinIds = next;
        savePins();
    }

    function launch(entry) {
        if (!entry) return;
        const id = entry.id || entry.name || "";
        if (id) {
            const u = Object.assign({}, usage);
            u[id] = (u[id] || 0) + 1;
            usage = u;
            saveUsage();
        }
        entry.execute();
    }

    function score(entry) {
        if (!entry) return 0;
        const id = entry.id || entry.name || "";
        return usage[id] || 0;
    }

    function savePins() {
        const json = JSON.stringify(pinIds);
        Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.config/dynamic-notch && printf '%s' \"$1\" > \"$2\"", "_", json, pinsPath]);
    }

    function saveUsage() {
        const json = JSON.stringify(usage);
        Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.local/state/dynamic-notch && printf '%s' \"$1\" > \"$2\"", "_", json, usagePath]);
    }

    Process {
        running: true
        command: ["sh", "-c", "cat ~/.config/dynamic-notch/pins.json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (!t) return;
                try {
                    const arr = JSON.parse(t);
                    if (Array.isArray(arr) && arr.length > 0) root.pinIds = arr;
                } catch (e) {}
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "cat ~/.local/state/dynamic-notch/launcher-usage.json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (!t) return;
                try {
                    const obj = JSON.parse(t);
                    if (obj && typeof obj === "object") root.usage = obj;
                } catch (e) {}
            }
        }
    }
}
