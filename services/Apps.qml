pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Application service: pinned icons and launch history for ranking.
Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/dynamic-notch"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/dynamic-notch"
    readonly property string pinsPath: configDir + "/pins.json"
    readonly property string usagePath: stateDir + "/launcher-usage.json"

    property var pinIds: []
    property var usage: ({})
    property bool _pinsLoaded: false
    property bool _pinsDirty: false
    property bool _usageDirty: false

    readonly property var allEntries: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    readonly property var pins: {
        const res = [];
        const seen = {};
        const _ = allEntries.length; // dependency on list updates
        for (const id of pinIds) {
            const e = findById(id);
            if (e && !seen[e.id]) {
                seen[e.id] = true;
                res.push(e);
            }
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

    function _canonicalId(id) {
        if (!id) return "";
        const e = findById(id);
        return (e && e.id) ? e.id : id;
    }

    function isPinned(id) {
        if (!id) return false;
        const canon = _canonicalId(id);
        for (let i = 0; i < pinIds.length; i++) {
            if (pinIds[i] === id || pinIds[i] === canon || _canonicalId(pinIds[i]) === canon)
                return true;
        }
        return false;
    }

    function togglePin(id) {
        if (!id) return;
        const canon = _canonicalId(id);
        const next = [];
        let removed = false;
        for (let i = 0; i < pinIds.length; i++) {
            const cur = pinIds[i];
            if (cur === id || cur === canon || _canonicalId(cur) === canon) {
                removed = true;
            } else {
                next.push(cur);
            }
        }
        if (!removed) next.push(canon);
        _pinsDirty = true;
        pinIds = next;
        savePins();
    }

    function launch(entry) {
        if (!entry) return;
        const id = entry.id || entry.name || "";
        if (id) {
            const u = Object.assign({}, usage);
            u[id] = (u[id] || 0) + 1;
            _usageDirty = true;
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
        Quickshell.execDetached([
            "sh", "-c",
            "mkdir -p \"$1\" && tmp=\"$2.tmp.$$\" && printf '%s' \"$3\" > \"$tmp\" && mv -f \"$tmp\" \"$2\"",
            "_", configDir, pinsPath, json
        ]);
    }

    function saveUsage() {
        const json = JSON.stringify(usage);
        Quickshell.execDetached([
            "sh", "-c",
            "mkdir -p \"$1\" && tmp=\"$2.tmp.$$\" && printf '%s' \"$3\" > \"$tmp\" && mv -f \"$tmp\" \"$2\"",
            "_", stateDir, usagePath, json
        ]);
    }

    Process {
        running: true
        command: ["sh", "-c", "[ -f \"$1\" ] && cat \"$1\" 2>/dev/null || true", "_", root.pinsPath]
        stdout: StdioCollector {
            onStreamFinished: {
                root._pinsLoaded = true;
                if (root._pinsDirty) return;
                const t = text.trim();
                if (!t) return;
                try {
                    const arr = JSON.parse(t);
                    if (Array.isArray(arr)) root.pinIds = arr;
                } catch (e) {}
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "[ -f \"$1\" ] && cat \"$1\" 2>/dev/null || true", "_", root.usagePath]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._usageDirty) return;
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
