pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// IPC для биндов Hyprland:
//   qs -p <путь> ipc call island toggle
Singleton {
    id: root
    signal toggleRequested()
    signal closeRequested()

    IpcHandler {
        target: "island"
        function toggle(): void { root.toggleRequested(); }
        function close(): void { root.closeRequested(); }
    }
}
