pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Загрузка CPU, память, диск, сеть, аптайм, температура и топ процессов.
Singleton {
    id: root

    property real cpu: 0          // 0..1
    property real mem: 0          // 0..1
    property real memUsedGb: 0
    property real memTotalGb: 0
    property real swap: 0
    property real swapUsedGb: 0
    property real swapTotalGb: 0
    property real disk: 0         // 0..1
    property string diskText: ""
    property int cpuTemp: -1      // °C
    property string uptime: ""
    property string netDown: "0 КБ/с"
    property string netUp: "0 КБ/с"
    property var cpuHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var topProcs: []     // [{ pid, comm, cpu, mem }]

    property real _prevTotal: 0
    property real _prevIdle: 0
    property real _prevRx: 0
    property real _prevTx: 0
    property string _tempPath: ""

    FileView { id: statF; path: "/proc/stat"; blockLoading: true }
    FileView { id: memF; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: netF; path: "/proc/net/dev"; blockLoading: true }
    FileView { id: upF; path: "/proc/uptime"; blockLoading: true }
    FileView { id: tempF; path: root._tempPath; blockLoading: true }

    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name 2>/dev/null) in k10temp|coretemp|zenpower|cpu_thermal) echo $h/temp1_input; exit;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: root._tempPath = text.trim()
        }
    }

    function fmtRate(bytesPerSec) {
        if (bytesPerSec < 1024) return Math.round(bytesPerSec) + " Б/с";
        const kb = bytesPerSec / 1024;
        if (kb < 1024) return kb.toFixed(0) + " КБ/с";
        return (kb / 1024).toFixed(1) + " МБ/с";
    }

    function update() {
        statF.reload();
        const f = statF.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        if (f.length >= 4) {
            const idle = f[3] + (f[4] || 0);
            const total = f.reduce((a, b) => a + b, 0);
            const dt = total - _prevTotal;
            if (_prevTotal > 0 && dt > 0) {
                cpu = Math.max(0, Math.min(1, 1 - (idle - _prevIdle) / dt));
                const hist = cpuHistory.slice(1);
                hist.push(cpu);
                cpuHistory = hist;
            }
            _prevTotal = total;
            _prevIdle = idle;
        }

        memF.reload();
        const m = memF.text();
        const get = k => {
            const r = new RegExp("^" + k + ":\\s+(\\d+)", "m").exec(m);
            return r ? Number(r[1]) : 0;
        };
        const total = get("MemTotal"), avail = get("MemAvailable");
        if (total > 0) {
            mem = (total - avail) / total;
            memUsedGb = (total - avail) / 1048576;
            memTotalGb = total / 1048576;
        }
        const stotal = get("SwapTotal"), sfree = get("SwapFree");
        if (stotal > 0) {
            swap = (stotal - sfree) / stotal;
            swapUsedGb = (stotal - sfree) / 1048576;
            swapTotalGb = stotal / 1048576;
        }

        netF.reload();
        const nlines = netF.text().split("\n").slice(2);
        let rx = 0, tx = 0;
        for (const ln of nlines) {
            const p = ln.trim().split(/[:\s]+/);
            if (p.length > 9 && p[0] !== "lo") {
                rx += Number(p[1]) || 0;
                tx += Number(p[9]) || 0;
            }
        }
        if (_prevRx > 0) {
            netDown = fmtRate(Math.max(0, (rx - _prevRx) / 2));
            netUp = fmtRate(Math.max(0, (tx - _prevTx) / 2));
        }
        _prevRx = rx;
        _prevTx = tx;

        upF.reload();
        const upSec = parseFloat(upF.text().split(" ")[0]) || 0;
        const d = Math.floor(upSec / 86400);
        const h = Math.floor((upSec % 86400) / 3600);
        const mn = Math.floor((upSec % 3600) / 60);
        uptime = (d > 0 ? d + "д " : "") + (h > 0 ? h + "ч " : "") + mn + "м";

        if (_tempPath !== "") {
            tempF.reload();
            const t = parseInt(tempF.text());
            cpuTemp = isNaN(t) ? -1 : Math.round(t / 1000);
        }
    }

    function refreshProcs() {
        psProc.running = false;
        psProc.running = true;
    }

    Process {
        id: psProc
        running: true
        command: ["sh", "-c", "LC_ALL=C df -BG / | awk 'NR==2{print $3\"/\"$2\" \"$5}'; LC_ALL=C ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6 | tail -n 5"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length > 0) {
                    const dfParts = lines[0].trim().split(/\s+/);
                    if (dfParts.length >= 2) {
                        root.diskText = dfParts[0].replace(/G/g, " ГБ");
                        const pct = parseInt(dfParts[1]);
                        if (!isNaN(pct)) root.disk = pct / 100;
                    }
                }
                const procs = [];
                for (let i = 1; i < lines.length; i++) {
                    const p = lines[i].trim().split(/\s+/);
                    if (p.length >= 4) {
                        procs.push({ pid: p[0], comm: p[1], cpu: p[2] + "%", mem: p[3] + "%" });
                    }
                }
                root.topProcs = procs;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.update()
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: root.refreshProcs()
    }
}
