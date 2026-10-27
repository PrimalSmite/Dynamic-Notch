pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Загрузка CPU, память и температура процессора.
Singleton {
    id: root

    property real cpu: 0          // 0..1
    property real mem: 0          // 0..1
    property real memUsedGb: 0
    property real memTotalGb: 0
    property int cpuTemp: -1      // °C, -1 если датчик не найден

    property real _prevTotal: 0
    property real _prevIdle: 0
    property string _tempPath: ""

    FileView { id: statF; path: "/proc/stat"; blockLoading: true }
    FileView { id: memF; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: tempF; path: root._tempPath; blockLoading: true }

    // Ищем датчик температуры CPU (AMD / Intel)
    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name 2>/dev/null) in k10temp|coretemp|zenpower|cpu_thermal) echo $h/temp1_input; exit;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: root._tempPath = text.trim()
        }
    }

    function update() {
        statF.reload();
        const f = statF.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        if (f.length >= 4) {
            const idle = f[3] + (f[4] || 0);
            const total = f.reduce((a, b) => a + b, 0);
            const dt = total - _prevTotal;
            if (_prevTotal > 0 && dt > 0)
                cpu = Math.max(0, Math.min(1, 1 - (idle - _prevIdle) / dt));
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

        if (_tempPath !== "") {
            tempF.reload();
            const t = parseInt(tempF.text());
            cpuTemp = isNaN(t) ? -1 : Math.round(t / 1000);
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.update()
    }
}
