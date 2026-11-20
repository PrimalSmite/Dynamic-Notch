pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard service based on cliphist + wl-paste.
// Synchronizes history in memory, generates image previews, and provides instant data to the panel.
Singleton {
    id: root

    property var entries: []
    readonly property int count: entries.length
    property bool pending: false
    property bool surfaceOpen: false
    property bool dirty: true
    property var delQueue: []
    property bool _watchPrimed: false
    property bool available: true
    property int _respawnFailures: 0
    property int _gen: 0

    signal copied()

    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/dynamic-notch/cliphist-thumbs/"
    readonly property string thumbScript: {
        const raw = Qt.resolvedUrl("../scripts/cliphist-thumbs.sh").toString();
        const path = raw.startsWith("file://") ? raw.substring(7) : raw;
        try { return decodeURIComponent(path); } catch (e) { return path; }
    }

    // Check required binaries once on startup so missing tools do not cause infinite respawn loops
    Process {
        id: depCheckProc
        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1 && echo OK || echo MISSING"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "OK") {
                    root.available = true;
                    watchProc.running = true;
                    root.refresh();
                } else {
                    root.available = false;
                }
            }
        }
    }

    function refresh() {
        if (!available) return;
        dirty = false;
        if (thumbProc.running || listProc.running || delProc.running || wipeProc.running || delQueue.length) {
            pending = true;
            return;
        }
        thumbProc.running = true;
    }

    function copy(entry) {
        if (!available || !entry || !/^\d+$/.test(String(entry.id)))
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", String(entry.id)]);
    }

    function remove(entry) {
        if (!available || !entry)
            return;
        const id = String(entry.id);
        if (!/^\d+$/.test(id))
            return;
        const kept = [];
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].id !== id)
                kept.push(entries[i]);
        }
        entries = kept;
        delQueue.push(id);
        pumpDeletes();
    }

    function pumpDeletes() {
        if (delProc.running || !delQueue.length)
            return;
        const id = delQueue.shift();
        delProc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", id];
        delProc.running = true;
    }

    function wipe() {
        if (!available) return;
        _gen++;
        delQueue = [];
        pending = false;
        delProc.running = false;
        thumbProc.running = false;
        listProc.running = false;
        entries = [];
        wipeProc.running = false;
        wipeProc.running = true;
    }

    Process {
        id: delProc
        onExited: {
            if (root.delQueue.length) {
                root.pumpDeletes();
            } else if (root.surfaceOpen) {
                root.pending = false;
                root.refresh();
            } else {
                root.dirty = true;
            }
        }
    }

    Process {
        id: watchProc
        command: ["wl-paste", "--watch", "echo", "x"]
        running: false
        stdout: SplitParser {
            onRead: {
                root._respawnFailures = 0;
                if (!root._watchPrimed) {
                    root._watchPrimed = true;
                } else {
                    root.copied();
                }
                if (root.surfaceOpen)
                    debounce.restart();
                else
                    root.dirty = true;
            }
        }
        onExited: {
            root._watchPrimed = false;
            if (!root.available) return;
            if (root._respawnFailures < 5) {
                root._respawnFailures++;
                respawn.interval = Math.min(30000, 2000 * Math.pow(2, root._respawnFailures - 1));
                respawn.restart();
            }
        }
    }

    Timer {
        id: respawn
        interval: 2000
        onTriggered: if (root.available) watchProc.running = true
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: if (root.surfaceOpen) root.refresh()
    }

    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
        onExited: {
            if (root.surfaceOpen) {
                root.pending = false;
                root.refresh();
            } else {
                root.dirty = true;
            }
        }
    }

    Process {
        id: thumbProc
        command: ["sh", root.thumbScript]
        onExited: {
            listProc._runGen = root._gen;
            listProc.running = true;
        }
    }

    Process {
        id: listProc
        property int _runGen: 0
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            id: listCollector
            onStreamFinished: {
                if (listProc._runGen !== root._gen) return;
                const lines = this.text.split("\n");
                const out = [];
                const metaRe = /^\[\[ binary data (.*) \]\]$/;
                const imgRe = /\b(png|jpg|jpeg|gif|bmp|webp)\b/;
                const splitRe = /^(\S+ \S+) (\w+) (\d+)x(\d+)$/;
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    const tab = line.indexOf("\t");
                    if (tab < 1)
                        continue;
                    const id = line.substring(0, tab);
                    if (!/^\d+$/.test(id))
                        continue;
                    const preview = line.substring(tab + 1);
                    const m = metaRe.exec(preview);
                    const isImage = m !== null && imgRe.test(m[1]);
                    let label = "";
                    let sizeLabel = "";
                    if (isImage) {
                        const p = splitRe.exec(m[1]);
                        label = p ? p[2] + " " + p[3] + "×" + p[4] : m[1];
                        sizeLabel = p ? p[1] : "";
                    }
                    out.push({
                        id: id,
                        preview: preview,
                        text: isImage ? label + " " + sizeLabel : preview,
                        lower: (isImage ? label + " " + sizeLabel : preview).toLowerCase(),
                        isImage: isImage,
                        label: label,
                        sizeLabel: sizeLabel,
                        thumb: isImage ? root.thumbDir + id + ".png" : ""
                    });
                }
                root.entries = out;
                if (root.pending) {
                    root.pending = false;
                    if (root.surfaceOpen)
                        Qt.callLater(root.refresh);
                    else
                        root.dirty = true;
                }
            }
        }
    }
}
