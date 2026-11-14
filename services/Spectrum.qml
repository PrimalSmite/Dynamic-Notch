pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Real-time 4-band audio spectrum powered by cava.
// Runs ONLY when at least one visible AudioWave consumer is active during playback.
Singleton {
    id: root

    property int activeConsumers: 0
    property var levels: [0, 0, 0, 0]
    readonly property bool shouldRun: activeConsumers > 0 && Media.playing

    onShouldRunChanged: {
        if (!shouldRun) {
            levels = [0, 0, 0, 0];
        }
    }

    Process {
        id: cavaProc
        running: root.shouldRun
        command: [
            "sh", "-c",
            "exec cava -p /dev/stdin <<'EOF'\n" +
            "[general]\n" +
            "framerate = 15\n" +
            "bars = 4\n" +
            "sleep_timer = 1\n" +
            "autosens = 1\n" +
            "[input]\n" +
            "method = pipewire\n" +
            "source = auto\n" +
            "[output]\n" +
            "method = raw\n" +
            "raw_target = /dev/stdout\n" +
            "data_format = ascii\n" +
            "ascii_max_range = 100\n" +
            "bar_delimiter = 59\n" +
            "[smoothing]\n" +
            "noise_reduction = 32\n" +
            "EOF"
        ]

        stdout: SplitParser {
            onRead: data => {
                if (!root.shouldRun) return;
                const parts = data.trim().split(";");
                if (parts.length < 4) return;
                const next = [
                    Math.max(0, Math.min(1, (parseInt(parts[0], 10) || 0) / 100)),
                    Math.max(0, Math.min(1, (parseInt(parts[1], 10) || 0) / 100)),
                    Math.max(0, Math.min(1, (parseInt(parts[2], 10) || 0) / 100)),
                    Math.max(0, Math.min(1, (parseInt(parts[3], 10) || 0) / 100))
                ];
                root.levels = next;
            }
        }
    }
}
