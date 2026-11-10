pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// IPC for Hyprland keybindings:
//   qs -p <path> ipc call island toggle
//   qs -p <path> ipc call island open launcher     (launcher, notifications, mixer, sysmon, recorder, timer, wallpaper, clipboard, notes, settings, power, calendar, weather, media)
//   qs -p <path> ipc call island close
//   qs -p <path> ipc call island nextPanel / prevPanel
//   qs -p <path> ipc call island volUp / volDown / mute
//   qs -p <path> ipc call island playPause / nextTrack / prevTrack
//   qs -p <path> ipc call island dnd / record
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
        function media(): void { root.openRequested("media"); }
        function mixer(): void { root.openRequested("mixer"); }
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
        function refreshWeather(): void { Weather.refresh(); }
        function askpass(msg: string, actionId: string, replyFile: string): void {
            Auth.openAskpass(msg, actionId, replyFile);
        }
    }
}
