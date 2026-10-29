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

    property int bitrateKbps: 30000      // 30 Мбит/с (максимальная чёткость без артефактов сжатия)
    property string codec: "auto"        // "auto" | "hevc" | "h264"
    property bool selectingRegion: false
    property string pendingMonitor: "screen"

    function start(monitorName) {
        if (recording || selectingRegion) return;
        pendingMonitor = monitorName || "screen";

        if (target === "region") {
            selectingRegion = true;
            slurpProc.running = false;
            slurpProc.running = true;
        } else {
            launchRecorder(pendingMonitor);
        }
    }

    function launchRecorder(captureTarget) {
        const ts = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        const out = outDir + "/rec_" + ts + ".mp4";
        lastFile = out;

        let audioArgs = "";
        if (audioDesktop && audioMic) audioArgs = "-a default_output -a default_input";
        else if (audioDesktop) audioArgs = "-a default_output";
        else if (audioMic) audioArgs = "-a default_input";

        const cursorArg = showCursor ? "-cursor yes" : "-cursor no";
        // Высокий битрейт 30 Мбит/с (CBR), полный цветовой диапазон ПК (0-255), постоянный фреймрейт (CFR)
        // и автоматический фоллбэк на кодирование процессором, если видеопамять GPU занята игрой.
        const qualArgs = "-bm cbr -q " + bitrateKbps + " -cr full -fm cfr -tune quality -k " + codec + " -fallback-cpu-encoding yes";

        const cmd = "mkdir -p '" + outDir + "' && exec gpu-screen-recorder -w \"" + captureTarget + "\" -f "
            + fps + " " + qualArgs + " " + cursorArg + " " + audioArgs + " -o '" + out + "'";

        elapsed = 0;
        recProc.command = ["sh", "-c", cmd];
        recProc.running = true;
        recording = true;
    }

    function stop() {
        if (selectingRegion) {
            Quickshell.execDetached(["pkill", "-x", "slurp"]);
            selectingRegion = false;
            return;
        }
        if (!recording) return;
        Quickshell.execDetached(["pkill", "-INT", "-f", "gpu-screen-recorder"]);
    }

    function refreshRecent() {
        listProc.running = false;
        listProc.running = true;
    }

    // Выбор прямоугольной области через slurp в формате WxH+X+Y, который требует gpu-screen-recorder
    Process {
        id: slurpProc
        command: ["sh", "-c", "sleep 0.2 && slurp -f '%wx%h+%x+%y' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.selectingRegion = false;
                const reg = text.trim();
                if (reg.length > 0 && reg.indexOf("x") > 0 && reg.indexOf("+") > 0) {
                    // Проверяем, что ширина и высота не нулевые
                    const dims = reg.split("+")[0].split("x");
                    const w = parseInt(dims[0], 10) || 0;
                    const h = parseInt(dims[1], 10) || 0;
                    if (w >= 16 && h >= 16) {
                        root.launchRecorder(reg);
                    }
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.selectingRegion = false;
            }
        }
    }

    Process {
        id: recProc
        onExited: (code, status) => {
            const wasElapsed = root.elapsed;
            root.recording = false;
            if ((code === 0 || code === 130) && wasElapsed >= 1 && root.lastFile) {
                Quickshell.execDetached(["notify-send", "-a", "Запись экрана", "Видео сохранено (30 Мбит/с)", root.lastFile]);
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
