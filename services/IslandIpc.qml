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
        function toggle() { root.toggleRequested(); }
        function close() { root.closeRequested(); }
        function open(panel: string) { root.openRequested(panel); }
        function media() { root.openRequested("media"); }
        function mixer() { root.openRequested("mixer"); }
        function nextPanel() { root.cycleRequested(1); }
        function prevPanel() { root.cycleRequested(-1); }
        function volUp() { Audio.step(0.05); }
        function volDown() { Audio.step(-0.05); }
        function mute() { Audio.toggleMute(); }
        function playPause() { if (Media.player && Media.player.canTogglePlaying) Media.player.togglePlaying(); }
        function nextTrack() { if (Media.player && Media.player.canGoNext) Media.player.next(); }
        function prevTrack() { if (Media.player && Media.player.canGoPrevious) Media.player.previous(); }
        function dnd() { Notifs.dnd = !Notifs.dnd; }
        function record() {
            if (Recorder.recording) Recorder.stop();
            else Recorder.start("screen");
        }
        function refreshWeather() { Weather.refresh(); }
        function askpass(msg: string, actionId: string, replyFile: string) {
            Auth.openAskpass(msg, actionId, replyFile);
        }
    }
}
