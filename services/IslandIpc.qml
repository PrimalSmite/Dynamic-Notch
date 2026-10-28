pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// IPC для биндов Hyprland:
//   qs -p <путь> ipc call island toggle
//   qs -p <путь> ipc call island open launcher     (launcher, notifications, mixer, sysmon, recorder, timer, wallpaper, clipboard, notes, settings, power, calendar, weather, media)
//   qs -p <путь> ipc call island close
//   qs -p <путь> ipc call island nextPanel / prevPanel
//   qs -p <путь> ipc call island volUp / volDown / mute
//   qs -p <путь> ipc call island playPause / nextTrack / prevTrack
//   qs -p <путь> ipc call island dnd / record
Singleton {
    id: root
    signal toggleRequested()
    signal closeRequested()
    signal openRequested(string panel)
    signal cycleRequested(int delta)

    IpcHandler {
        target: "island"
        function toggle(): void { root.toggleRequested(); }
        function close(): void { root.closeRequested(); }
        function open(panel: string): void { root.openRequested(panel); }
        function nextPanel(): void { root.cycleRequested(1); }
        function prevPanel(): void { root.cycleRequested(-1); }
        function volUp(): void { Audio.step(0.05); }
        function volDown(): void { Audio.step(-0.05); }
        function mute(): void { Audio.toggleMute(); }
        function playPause(): void { if (Media.player && Media.player.canTogglePlaying) Media.player.togglePlaying(); }
        function nextTrack(): void { if (Media.player && Media.player.canGoNext) Media.player.next(); }
        function prevTrack(): void { if (Media.player && Media.player.canGoPrevious) Media.player.previous(); }
        function dnd(): void { Notifs.dnd = !Notifs.dnd; }
        function record(): void {
            if (Recorder.recording) Recorder.stop();
            else Recorder.start("screen");
        }
        function askpass(msg: string, actionId: string, replyFile: string): void {
            Auth.openAskpass(msg, actionId, replyFile);
        }
    }
}
