pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// IPC for Hyprland keybindings:
//   qs -p <path> ipc call island toggle
//   qs -p <path> ipc call island open launcher     (launcher, notifications, mixer, sysmon, recorder, timer, wallpaper, clipboard, notes, settings, power, calendar, weather, media, auth)
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
        function playPause() { Media.togglePlay(); }
        function nextTrack() { Media.next(); }
        function prevTrack() { Media.prev(); }
        function dnd() { Notifs.dnd = !Notifs.dnd; }
        function record() {
            if (Recorder.recording || Recorder.selectingRegion || Recorder.counting) Recorder.stop();
            else Recorder.start("screen");
        }
        function refreshWeather() { Weather.refresh(); }
        function askpass(msg: string, actionId: string, replyFile: string) {
            Auth.openAskpass(msg, actionId, replyFile);
        }
        function liveStart(id: string, label: string, icon: string, progress: real) {
            LiveActivity.startTask(id, label, icon, progress);
        }
        function liveProgress(id: string, progress: real, label: string) {
            LiveActivity.updateTask(id, progress, label);
        }
        function liveDone(id: string, ok: bool) {
            LiveActivity.finishTask(id, ok);
        }
        function liveClear(id: string) {
            LiveActivity.clearTask(id);
        }
        function toggleMic() { Audio.toggleMic(); }
        function toggleKeepAwake() { SysToggles.toggleKeepAwake(); }
        function toggleNightLight() { SysToggles.toggleNightLight(); }
        function screenshotRegion() { SysToggles.takeScreenshotRegion(); }
        function screenshotFull() { SysToggles.takeScreenshotFull(); }
        function screenshotTaken(mode: string) {
            Clipboard.suppressCopied(1500);
            SysToggles.screenshotTaken(mode || "region");
        }
    }
}
