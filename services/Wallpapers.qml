pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Wallpaper management service: search images by folder, save selection, and apply.
Singleton {
    id: root

    property var allWalls: []
    property var folders: []
    property string selectedFolder: ""
    property string currentWall: ""
    property string customDir: ""
    property bool active: false
    property bool scanning: false

    readonly property var walls: {
        if (!selectedFolder) return allWalls;
        const prefix = selectedFolder.endsWith("/") ? selectedFolder : (selectedFolder + "/");
        return allWalls.filter(w => w.startsWith(prefix));
    }

    readonly property string stateFile: Quickshell.env("HOME") + "/.cache/dynamic-notch-wallpaper"
    readonly property string dirFile: Quickshell.env("HOME") + "/.cache/dynamic-notch-walldir"

    function fileUrl(path) {
        if (!path) return "";
        if (path.startsWith("file://")) return path;
        return "file://" + encodeURI(path);
    }

    function apply(path) {
        if (!path) return;
        currentWall = path;
        active = true;

        const script = '
            W="$1"
            mkdir -p ~/.cache
            printf "%s" "$W" > ~/.cache/dynamic-notch-wallpaper
            ln -sf "$W" ~/.cache/current-wallpaper

            if command -v awww >/dev/null 2>&1; then
                pgrep -x awww-daemon >/dev/null 2>&1 || (awww-daemon >/dev/null 2>&1 & sleep 0.25)
                awww img "$W" --transition-type grow --transition-fps 60 --transition-duration 1.0 >/dev/null 2>&1 &
            elif [ -x ~/.local/bin/awww ]; then
                pgrep -x awww-daemon >/dev/null 2>&1 || (~/.local/bin/awww-daemon >/dev/null 2>&1 & sleep 0.25)
                ~/.local/bin/awww img "$W" --transition-type grow --transition-fps 60 --transition-duration 1.0 >/dev/null 2>&1 &
            elif [ -x ~/.cargo/bin/awww ]; then
                pgrep -x awww-daemon >/dev/null 2>&1 || (~/.cargo/bin/awww-daemon >/dev/null 2>&1 & sleep 0.25)
                ~/.cargo/bin/awww img "$W" --transition-type grow --transition-fps 60 --transition-duration 1.0 >/dev/null 2>&1 &
            elif command -v swww >/dev/null 2>&1; then
                pgrep -x swww-daemon >/dev/null 2>&1 || (swww-daemon >/dev/null 2>&1 & sleep 0.25)
                swww img "$W" --transition-type grow --transition-fps 60 --transition-duration 1.0 >/dev/null 2>&1 &
            fi

            if command -v hyprpaper >/dev/null 2>&1 && command -v hyprctl >/dev/null 2>&1; then
                if pgrep -x hyprpaper >/dev/null 2>&1; then
                    hyprctl hyprpaper preload "$W" >/dev/null 2>&1
                    hyprctl hyprpaper wallpaper ",$W" >/dev/null 2>&1
                    for m in $(hyprctl monitors -j 2>/dev/null | grep -o "\"name\": *\"[^\"]*\"" | cut -d"\"" -f4); do
                        hyprctl hyprpaper wallpaper "$m,$W" >/dev/null 2>&1
                    done
                fi
            fi
        ';
        Quickshell.execDetached(["sh", "-c", script, "_", path]);
    }

    function pickRandom() {
        const list = walls;
        if (list.length === 0) return "";
        let idx = Math.floor(Math.random() * list.length);
        if (list.length > 1 && list[idx] === currentWall)
            idx = (idx + 1) % list.length;
        apply(list[idx]);
        return list[idx];
    }

    function pickFolderDialog() {
        if (folderPickerProc.running) return;
        folderPickerProc.running = true;
    }

    function pickFileDialog() {
        if (filePickerProc.running) return;
        filePickerProc.running = true;
    }

    function refresh() {
        if (scanProc.running) return;
        scanning = true;
        scanProc.running = true;
    }

    function rebuildFolders(list) {
        const map = {};
        const order = [];
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            const slash = p.lastIndexOf("/");
            if (slash <= 0) continue;
            const dir = p.substring(0, slash);
            if (!map[dir]) {
                map[dir] = 0;
                order.push(dir);
            }
            map[dir]++;
        }
        const res = [{ name: "All", path: "", count: list.length }];
        for (let i = 0; i < order.length; i++) {
            const d = order[i];
            const base = d.split("/").pop() || d;
            res.push({
                name: base === "cachyos-wallpapers" ? "CachyOS" : base,
                path: d,
                count: map[d]
            });
        }
        folders = res;
        if (selectedFolder !== "" && !map[selectedFolder])
            selectedFolder = "";
    }

    // Initialize saved wallpaper on startup
    Process {
        id: initProc
        running: true
        command: [
            "sh", "-c",
            "if [ -f ~/.cache/dynamic-notch-wallpaper ]; then " +
            "  W=$(cat ~/.cache/dynamic-notch-wallpaper); " +
            "  [ -f \"$W\" ] && printf 'SAVED:%s\\n' \"$W\"; " +
            "fi; " +
            "if [ -f ~/.cache/dynamic-notch-walldir ]; then " +
            "  D=$(cat ~/.cache/dynamic-notch-walldir); " +
            "  [ -d \"$D\" ] && printf 'DIR:%s\\n' \"$D\"; " +
            "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (line.startsWith("SAVED:")) {
                        const w = line.substring(6);
                        if (w) {
                            root.currentWall = w;
                            root.active = true;
                        }
                    } else if (line.startsWith("DIR:")) {
                        root.customDir = line.substring(4);
                    }
                }
                root.refresh();
            }
        }
    }

    // Search wallpapers in user and system directories
    Process {
        id: scanProc
        command: [
            "sh", "-c",
            "CUSTOM=$( [ -f ~/.cache/dynamic-notch-walldir ] && cat ~/.cache/dynamic-notch-walldir || true ); " +
            "for d in \"$CUSTOM\" " +
            "  \"$HOME/Pictures/Wallpapers\" \"$HOME/Pictures/wallpapers\" " +
            "  \"$HOME/Wallpapers\" \"$HOME/wallpapers\" " +
            "  \"$HOME/Pictures\" \"$HOME/Изображения\" " +
            "  \"$HOME/.local/share/wallpapers\" " +
            "  \"/usr/share/wallpapers\" \"/usr/share/backgrounds\"; do " +
            "  [ -n \"$d\" ] && [ -d \"$d\" ] && find -L \"$d\" -maxdepth 3 -type f " +
            "    \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null; " +
            "done | awk '!seen[$0]++' | head -n 160"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.scanning = false;
                const list = text.trim().split("\n").filter(s => s.length > 0);
                root.allWalls = list;
                root.rebuildFolders(list);
            }
        }
    }

    // Folder selection dialog
    Process {
        id: folderPickerProc
        command: [
            "sh", "-c",
            "if command -v zenity >/dev/null 2>&1; then " +
            "  zenity --file-selection --directory --title='Select Wallpaper Folder' 2>/dev/null; " +
            "elif command -v kdialog >/dev/null 2>&1; then " +
            "  kdialog --getexistingdirectory \"$HOME\" --title 'Select Wallpaper Folder' 2>/dev/null; " +
            "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const picked = text.trim();
                if (!picked) return;
                root.customDir = picked;
                root.selectedFolder = picked;
                Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.cache && printf '%s' \"$1\" > ~/.cache/dynamic-notch-walldir", "_", picked]);
                root.refresh();
            }
        }
    }

    // Single wallpaper file selection dialog
    Process {
        id: filePickerProc
        command: [
            "sh", "-c",
            "if command -v zenity >/dev/null 2>&1; then " +
            "  zenity --file-selection --title='Select Wallpaper Image' --file-filter='Images | *.png *.jpg *.jpeg *.webp' 2>/dev/null; " +
            "elif command -v kdialog >/dev/null 2>&1; then " +
            "  kdialog --getopenfilename \"$HOME\" 'Image Files (*.png *.jpg *.jpeg *.webp)' 2>/dev/null; " +
            "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const picked = text.trim();
                if (!picked) return;
                if (root.allWalls.indexOf(picked) < 0) {
                    root.allWalls = [picked].concat(root.allWalls);
                    root.rebuildFolders(root.allWalls);
                }
                root.apply(picked);
            }
        }
    }
}
