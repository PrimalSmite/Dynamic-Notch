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

    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/dynamic-notch/cliphist-thumbs/"
    readonly property string thumbScript: {
        const raw = Qt.resolvedUrl("../scripts/cliphist-thumbs.sh").toString();
        return raw.startsWith("file://") ? raw.substring(7) : raw;
    }

    function refresh() {
        dirty = false;
        if (thumbProc.running || listProc.running || delProc.running || delQueue.length) {
            pending = true;
            return;
        }
        thumbProc.running = true;
    }

    function copy(entry) {
        if (!entry || !/^\d+$/.test(String(entry.id)))
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", String(entry.id)]);
    }

    function remove(entry) {
        if (!entry)
            return;
        var id = String(entry.id);
        if (!/^\d+$/.test(id))
            return;
        var kept = [];
        for (var i = 0; i < entries.length; i++) {
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
        var id = delQueue.shift();
        delProc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", id];
        delProc.running = true;
    }

    function wipe() {
        entries = [];
        wipeProc.running = true;
    }

    Process {
        id: delProc
        onExited: {
            if (root.delQueue.length)
                root.pumpDeletes();
            else if (root.surfaceOpen)
                root.refresh();
            else
                root.dirty = true;
        }
    }

    Process {
        id: watchProc
        command: ["wl-paste", "--watch", "echo", "x"]
        running: true
        stdout: SplitParser {
            onRead: {
                if (root.surfaceOpen)
                    debounce.restart();
                else
                    root.dirty = true;
            }
        }
        onExited: respawn.restart()
    }

    Timer {
        id: respawn
        interval: 2000
        onTriggered: watchProc.running = true
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
            if (root.surfaceOpen)
                root.refresh();
            else
                root.dirty = true;
        }
    }

    Process {
        id: thumbProc
        command: ["sh", root.thumbScript]
        onExited: listProc.running = true
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            id: listCollector
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];
                var metaRe = /^\[\[ binary data (.*) \]\]$/;
                var imgRe = /\b(png|jpg|jpeg|gif|bmp|webp)\b/;
                var splitRe = /^(\S+ \S+) (\w+) (\d+)x(\d+)$/;
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    var tab = line.indexOf("\t");
                    if (tab < 1)
                        continue;
                    var id = line.substring(0, tab);
                    if (!/^\d+$/.test(id))
                        continue;
                    var preview = line.substring(tab + 1);
                    var m = metaRe.exec(preview);
                    var isImage = m !== null && imgRe.test(m[1]);
                    var label = "";
                    var sizeLabel = "";
                    if (isImage) {
                        var p = splitRe.exec(m[1]);
                        label = p ? p[2] + " " + p[3] + "×" + p[4] : m[1];
                        sizeLabel = p ? p[1] : "";
                    }
                    out.push({
                        id: id,
                        raw: line,
                        preview: preview,
                        text: isImage ? label + " " + sizeLabel : preview,
                        lower: (isImage ? label + " " + sizeLabel : preview).toLowerCase(),
                        isImage: isImage,
                        isImg: isImage,
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

    Component.onCompleted: refresh()
}
