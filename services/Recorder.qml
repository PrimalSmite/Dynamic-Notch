pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Сервис записи экрана (gpu-screen-recorder + slurp).
Singleton {
    id: root

    property bool recording: false
    property int elapsed: 0
    readonly property string elapsedText: {
        const m = Math.floor(elapsed / 60);
        const s = elapsed % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    property string target: "screen"     // "screen" | "region"
    property int fps: 60
    property bool audioDesktop: true
    property bool audioMic: false
    property bool showCursor: true
    property string lastFile: ""
    property var recentFiles: []

    readonly property string outDir: Quickshell.env("HOME") + "/Videos/Recordings"

    property string quality: "ultra"     // "ultra" | "very_high"
    property string codec: "auto"        // "auto" | "hevc" | "h264"

    function start(monitorName) {
        if (recording) return;
        const ts = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        const out = outDir + "/rec_" + ts + ".mp4";
        lastFile = out;

        let audioArgs = "";
        if (audioDesktop && audioMic) audioArgs = "-a default_output -a default_input";
        else if (audioDesktop) audioArgs = "-a default_output";
        else if (audioMic) audioArgs = "-a default_input";

        const cursorArg = showCursor ? "-cursor yes" : "-cursor no";
        const mon = monitorName || "screen";
        const qualArgs = "-q " + quality + " -tune quality -k " + codec;

        let cmd = "";
        if (target === "region") {
            cmd = "mkdir -p '" + outDir + "' && sleep 0.25 && REG=$(slurp -f '%wx%h+%x+%y') && [ -n \"$REG\" ] && exec gpu-screen-recorder -w \"$REG\" -f "
                + fps + " " + qualArgs + " " + cursorArg + " " + audioArgs + " -o '" + out + "'";
        } else {
            cmd = "mkdir -p '" + outDir + "' && exec gpu-screen-recorder -w " + mon + " -f "
                + fps + " " + qualArgs + " " + cursorArg + " " + audioArgs + " -o '" + out + "'";
        }

        elapsed = 0;
        recProc.command = ["sh", "-c", cmd];
        recProc.running = true;
        recording = true;
    }

    function stop() {
        if (!recording) return;
        Quickshell.execDetached(["pkill", "-INT", "-f", "gpu-screen-recorder"]);
    }

    function refreshRecent() {
        listProc.running = false;
        listProc.running = true;
    }

    Process {
        id: recProc
        onExited: (code, status) => {
            root.recording = false;
            if (root.elapsed >= 1 && root.lastFile) {
                Quickshell.execDetached(["notify-send", "-a", "Запись экрана", "Видео сохранено", root.lastFile]);
            }
            root.refreshRecent();
        }
    }

    Process {
        id: listProc
        running: true
        command: ["sh", "-c", "mkdir -p ~/Videos/Recordings && ls -1t ~/Videos/Recordings/*.mp4 2>/dev/null | head -6"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(s => s.length > 0);
                root.recentFiles = lines;
            }
        }
    }

    Timer {
        interval: 1000
        running: root.recording
        repeat: true
        onTriggered: root.elapsed += 1
    }
}
