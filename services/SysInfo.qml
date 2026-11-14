pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// CPU usage, memory, disk, network, uptime, temperature, and top processes.
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
    property string netDown: "0 KB/s"
    property string netUp: "0 KB/s"
    property var cpuHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var topProcs: []     // [{ pid, comm, cpu, mem }]

    property int _highCpuStreak: 0
    property bool highLoadAlert: false

    property real _prevTotal: 0
    property real _prevIdle: 0
    property real _prevRx: 0
    property real _prevTx: 0
    property string _tempPath: ""
    property bool _firstHistorySample: true

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
        if (bytesPerSec < 1024) return Math.round(bytesPerSec) + " B/s";
        const kb = bytesPerSec / 1024;
        if (kb < 1024) return kb.toFixed(0) + " KB/s";
        return (kb / 1024).toFixed(1) + " MB/s";
    }

    property int _uptimeCounter: 0

    function update() {
        statF.reload();
        const f = statF.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        if (f.length >= 4) {
            const idle = f[3] + (f[4] || 0);
            const total = f.reduce((a, b) => a + b, 0);
            const dt = total - _prevTotal;
            if (_prevTotal > 0 && dt > 0) {
                cpu = Math.max(0, Math.min(1, 1 - (idle - _prevIdle) / dt));
                if (cpu >= 0.85) {
                    _highCpuStreak++;
                    if (_highCpuStreak >= 2) highLoadAlert = true;
                } else if (cpu < 0.78) {
                    _highCpuStreak = 0;
                    highLoadAlert = false;
                }
                let hist = cpuHistory.slice();
                if (root._firstHistorySample) {
                    root._firstHistorySample = false;
                    hist = Array(30).fill(cpu);
                } else {
                    hist.shift();
                    hist.push(cpu);
                }
                cpuHistory = hist;
            }
            _prevTotal = total;
            _prevIdle = idle;
        }

        memF.reload();
        const m = memF.text();
        let total = 0, avail = 0, stotal = 0, sfree = 0;
        const mlines = m.split("\n");
        for (let i = 0; i < mlines.length; i++) {
            const ln = mlines[i];
            if (ln.startsWith("MemTotal:")) total = parseInt(ln.slice(9).trim(), 10) || 0;
            else if (ln.startsWith("MemAvailable:")) avail = parseInt(ln.slice(13).trim(), 10) || 0;
            else if (ln.startsWith("SwapTotal:")) stotal = parseInt(ln.slice(10).trim(), 10) || 0;
            else if (ln.startsWith("SwapFree:")) sfree = parseInt(ln.slice(9).trim(), 10) || 0;
            if (total > 0 && avail > 0 && stotal > 0 && sfree > 0) break;
        }
        if (total > 0) {
            mem = (total - avail) / total;
            memUsedGb = (total - avail) / 1048576;
            memTotalGb = total / 1048576;
        }
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

        // Uptime changes with minute resolution, refresh every 30 seconds (15 ticks of 2s)
        if (++_uptimeCounter >= 15 || uptime === "") {
            _uptimeCounter = 0;
            upF.reload();
            const upSec = parseFloat(upF.text().split(" ")[0]) || 0;
            const d = Math.floor(upSec / 86400);
            const h = Math.floor((upSec % 86400) / 3600);
            const mn = Math.floor((upSec % 3600) / 60);
            uptime = (d > 0 ? d + "d " : "") + (h > 0 ? h + "h " : "") + mn + "m";
        }

        if (_tempPath !== "") {
            tempF.reload();
            const t = parseInt(tempF.text());
            cpuTemp = isNaN(t) ? -1 : Math.round(t / 1000);
        }
    }

    property int activeClients: 0
    property double _prevProcCpuTotal: 0
    property var _prevProcMap: ({})
    property var _prevCpuPctMap: ({})

    onActiveClientsChanged: {
        if (activeClients > 0) {
            refreshProcs();
        }
    }

    function fmtMemBtop(rssKb) {
        const mb = rssKb / 1024;
        if (mb >= 1024) return (mb / 1024).toFixed(1) + "G";
        if (mb >= 100) return Math.round(mb) + "M";
        return mb.toFixed(0) + "M";
    }

    function refreshProcs() {
        if (activeClients <= 0 && _prevProcCpuTotal > 0) return;
        if (psProc.running) return;
        psProc.running = true;
    }

    Process {
        id: psProc
        running: false
        command: [
            "sh", "-c",
            "LC_ALL=C df -BG / 2>/dev/null | awk 'NR==2{print \"DF\\t\" $3\"/\"$2 \"\\t\" $5}'; " +
            "LC_ALL=C awk '" +
            "FILENAME == \"/proc/stat\" && /^cpu / { total = $2+$3+$4+$5+$6+$7+$8+$9; print \"CPU\\t\" total; nextfile } " +
            "FNR == 1 { " +
            "  if (match($0, /^[0-9]+ \\(.*\\) [^ ]+/)) { " +
            "    pid = $1; s = $0; sub(/^[0-9]+ \\(/, \"\", s); rest = s; sub(/^.*\\) /, \"\", rest); " +
            "    comm = substr(s, 1, length(s) - length(rest) - 2); " +
            "    split(rest, f, \" \"); ticks = f[12] + f[13]; rss_kb = f[22] * 4; " +
            "    if (ticks > 0 || rss_kb > 4096) printf \"P\\t%s\\t%s\\t%.0f\\t%.0f\\n\", pid, comm, ticks, rss_kb " +
            "  } " +
            "}' /proc/stat /proc/[0-9]*/stat 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                let totalCpu = 0;
                const newMap = {};
                const rawProcs = [];

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    if (!line) continue;
                    const p = line.split("\t");
                    if (p[0] === "DF" && p.length >= 3) {
                        root.diskText = p[1].replace(/G/g, " GB");
                        const pct = parseInt(p[2]);
                        if (!isNaN(pct)) root.disk = pct / 100;
                    } else if (p[0] === "CPU" && p.length >= 2) {
                        totalCpu = parseFloat(p[1]) || 0;
                    } else if (p[0] === "P" && p.length >= 5) {
                        const pid = p[1];
                        const comm = p[2] || "process";
                        const ticks = parseFloat(p[3]) || 0;
                        const rssKb = parseFloat(p[4]) || 0;
                        newMap[pid] = ticks;
                        rawProcs.push({ pid: pid, comm: comm, ticks: ticks, rssKb: rssKb });
                    }
                }

                const prevTotal = root._prevProcCpuTotal;
                const prevMap = root._prevProcMap;
                const prevCpuMap = root._prevCpuPctMap;
                const dt = totalCpu - prevTotal;

                root._prevProcCpuTotal = totalCpu;
                root._prevProcMap = newMap;

                if (prevTotal <= 0 || dt <= 0) {
                    bootstrapTimer.restart();
                    return;
                }

                const nextCpuMap = {};
                const computed = [];
                for (let i = 0; i < rawProcs.length; i++) {
                    const item = rawProcs[i];
                    const oldTicks = prevMap[item.pid];
                    const dTicks = (oldTicks !== undefined) ? Math.max(0, item.ticks - oldTicks) : 0;
                    const cpuVal = Math.min(100, (100.0 * dTicks) / dt);
                    const oldCpu = prevCpuMap[item.pid] || 0;
                    const lazyCpu = cpuVal * 0.7 + oldCpu * 0.3;
                    nextCpuMap[item.pid] = lazyCpu;

                    computed.push({
                        pid: item.pid,
                        comm: item.comm,
                        cpuNum: cpuVal,
                        sortScore: lazyCpu,
                        cpu: cpuVal.toFixed(1) + "%",
                        rssKb: item.rssKb,
                        mem: root.fmtMemBtop(item.rssKb)
                    });
                }
                root._prevCpuPctMap = nextCpuMap;

                computed.sort((a, b) => {
                    if (Math.abs(b.sortScore - a.sortScore) > 0.05) return b.sortScore - a.sortScore;
                    if (Math.abs(b.cpuNum - a.cpuNum) > 0.05) return b.cpuNum - a.cpuNum;
                    return b.rssKb - a.rssKb;
                });

                root.topProcs = computed.slice(0, 5);
            }
        }
    }

    Timer {
        id: bootstrapTimer
        interval: 350
        repeat: false
        running: false
        onTriggered: root.refreshProcs()
    }

    Timer {
        id: updateTimer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.update()
    }

    Timer {
        interval: 2000
        running: root.activeClients > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshProcs()
    }
}
