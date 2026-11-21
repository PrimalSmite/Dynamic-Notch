# Dynamic Notch Architecture & Contracts

## Structure
- `shell.qml` → `ShellRoot` that spawns:
  - Wallpaper background `PanelWindow` per screen (`WlrLayer.Background`, `Wallpapers` service).
  - `Island.qml` per screen (`WlrLayer.Overlay`, renders the notch, Live Activity wings, OSD popups, expanded dashboard, and **a single opened panel**).
- `services/*.qml` — singletons (`pragma Singleton`, root `Singleton {}`), import with `import qs.services`.
- `components/*.qml` — shared UI components, import with `import qs.components`.
- `panels/<Key>Panel.qml` — lazy-loaded panels. Key → file: `launcher` → `panels/LauncherPanel.qml`, `clipboard` → `panels/ClipboardPanel.qml`, etc.
  - Dock panels (`panelOrder`): `launcher`, `notifications`, `mixer`, `sysmon`, `recorder`, `timer`, `wallpaper`, `clipboard`, `notes`, `settings`, `power`.
  - Contextual panels: `calendar`, `weather`, `media`, `auth`.
- `scripts/` — helper scripts:
  - `run.sh` — low-memory launcher (`MALLOC_ARENA_MAX=2`, `GLIBC_TUNABLES=glibc.malloc.hugetlb=0`).
  - `cliphist-thumbs.sh` + `magick-policy/policy.xml` — sandboxed ImageMagick thumbnail generator for `Clipboard.qml`.
  - `sudo-askpass.sh` — `SUDO_ASKPASS` helper communicating with `Auth.qml` via `IslandIpc` and a runtime FIFO.
- `native/` — experimental standalone C++20 / Wayland Layer-Shell / OpenGL ES 3.0 prototype using `MockServices` (separate from the main Quickshell codebase).

## Panel Contract
```qml
import QtQuick
import qs.services
import qs.components

Item {
    id: root
    property var host: null             // Island: host.closePanel(), host.backToDashboard(), host.collapse(), host.openPanel("key")
    property bool wantsKeyboard: false  // true -> panel receives forceActiveFocus() after loading
    implicitHeight: ...                 // REQUIRED. Width is set by host. Keep height <= Theme.px(460).
}
```
- Panels are loaded via `Loader` only when open (`win.loadedPanel`), so perform heavy work (`Process`, scanning) upon load or on demand. Keep persistent state in `services/*.qml`.
- `Esc` closes the panel / collapses the notch (handled by `Island.qml`). `Backspace` or right-click returns to the dashboard (`backToDashboard()`). If a panel needs `Esc` itself (e.g. exiting an inline editor or modal), handle it in `Keys.onEscapePressed` and set `event.accepted = true`.
- `PanelWindow` `implicitHeight` must remain static (screen height) — never bind it to the animated notch height, or panel animations will break. Click-through is controlled via `mask: Region`.
- The window grabs keyboard input (`WlrKeyboardFocus.Exclusive`, or `OnDemand` while a tray menu is open, + `HyprlandFocusGrab` with `grabArmTimer` debounce) while in `dashboard` or `panel` mode.
- Clicking outside the notch collapses it. After launching an app or copying content, call `host.collapse()`.

## Style & Shared Components
- All dimensions must use `Theme.px(N)` (scaled by `Theme.s`, bound to `IslandPrefs.uiScale`). No bare pixel values.
- Fonts: `Theme.fontFamily` (UI, configurable in Settings), `Theme.monoFamily` (`JetBrainsMono Nerd Font Mono`), `Theme.iconFamily` (`Material Symbols Rounded`), `Theme.glyphFamily` (`Hack Nerd Font Propo`).
- Icons: `Icon { name: "<material symbol>" }`.
- Colors: `Theme.text`, `Theme.text2`, `Theme.text3`, `Theme.card`, `Theme.cardHover`, `Theme.track`, `Theme.divider`, semantic accents (`Theme.warn`, `Theme.alert`, `Theme.ok`), and palette accents (`Theme.blue`, `Theme.green`, `Theme.orange`, `Theme.yellow`, `Theme.red`, `Theme.pink`, `Theme.purple`, `Theme.teal`, `Theme.mint`, `Theme.accent`).
- Animations: `Behavior on x { Spring {} }` — iOS-style spring (`Theme.springK`, `Theme.springDamp`). Press feedback: scale `0.85–0.9`; hover: `Theme.cardHover`.
- Shared components (`components/`):
  - Core primitives: `Icon`, `Bar` (progress/slider: `value`, `tint`, `interactive`, `moved(v)`), `Spring`, `MorphView`, `Caret`, `NotchShape`, `ProgressRing`, `AudioWave`, `RollingClock`.
  - Dashboard & cards: `StatTile`, `MediaCard`, `TrackCard`, `VolumeCard`, `Workspaces`, `StripButton`.
  - Live Activity: `LiveWing`, `LiveSlotContent`, `DuoBubble`.

## Service Contracts Island Relies On
Do not rename or break these properties/signals — `Island.qml` and Live Activity wings bind to them directly:
- `IslandIpc`: `IpcHandler { target: "island" }` emitting `toggleRequested()`, `closeRequested()`, `openRequested(panel)`, `cycleRequested(delta)` and dispatching audio/media/recorder/live-task/askpass/screenshot actions.
- `IslandPrefs`: persistent user preferences in `~/.config/dynamic-notch/preferences.json` (`uiScale`, `fontSize`, `fontFamily`, `compactWidget`, `liveWingsEnabled`, `liveActivityStyle`, `hideInGames`, `recCountdown`, OSD toggles, etc.).
- `LiveActivity`: priority queue (`activeItems`, `primaryKind`, `secondaryItems`, `isSplitMode`), external IPC task slot (`ipcTask`, `startTask`, `updateTask`, `finishTask`, `clearTask`), `openMenu(kind, host)`, `quickAction(kind, button)`.
- `Notifs`: `list`, `unread`, `dnd`, signal `popup(n)`, `markRead()`, `dismiss(n)`, `clear()`, `invoke(n, actionId)`. Item shape: `{ id, appName, appIcon, image, summary, body, time, urgency, actions: [{id,text}] }`.
- `Weather`: `ready`, `temp`, `icon`, `iconColor`, `desc`, `city`, `hourly`, `daily`, `refresh()`, `setLocation()`, `searchCities()`.
- `Apps`: `pins` (`DesktopEntry` array), `allEntries`, `launch(entry)`, `togglePin(id)`, `score(entry)`.
- `Timers`: `running`, `paused`, `mode` (`"timer"` | `"stopwatch"`), `display`, `compactDisplay`, `progress`, signal `finished()`.
- `Recorder`: `recording`, `counting`, `selectingRegion`, `elapsed`, `elapsedText`, `stop()`, `start(monitorName, forceTarget)`, signals `countdownStarted(total)`, `countdownTick(left)`, `countdownCancelled()`, `recordingStarted()`, `recordingSaved(filePath, durationText)`.
- `Audio`: `ready`, `volume`, `muted`, `icon`, `sinkName`, `sinkIcon`, `micMuted`, `micInUse`, `setVolume(v)`, `step(d)`, `toggleMute()`, `toggleMic()`, signals `volumeStepped(delta, boundary)`, `micMuteToggled(muted)`, `sinkSwitched(name, icon)`.
- `Media`: `player`, `playing`, `trackTitle`, `trackArtist`, `trackArtUrl`, `trackAccent`, `activeConsumers`, `togglePlay()`, `next()`, `prev()`, signals `skipRequested(dir)`, `trackChanged(title, artist, artUrl, dir)`.
- `Keyboard`: `layout`, `shortCode`, `capsLock`, `next()`, signal `switched()`.
- `Clipboard`: `entries`, `count`, `lastKind`, `lastPreview`, `lastColorHex`, `copy(entry)`, `remove(entry)`, `wipe()`, `suppressCopied(ms)`, signal `copied()`.
- `SysInfo`: `cpu`, `mem`, `memUsedGb`, `memTotalGb`, `disk`, `cpuTemp`, `uptime`, `netDown`, `netUp`, `cpuHistory`, `topProcs`, `highLoadAlert`, `activeClients`.
- `SysToggles`: `nightLight`, `keepAwake`, `gameMode`, `toggleNightLight()`, `toggleKeepAwake()`, `toggleGameMode()`, `takeScreenshotRegion()`, `takeScreenshotFull()`, signals `modeToggled(modeKey, enabled)`, `screenshotTaken(mode)`.
- `Auth`: `active`, `message`, `actionId`, `promptText`, `errorText`, `submitting`, `openAskpass(msg, actId, replyFile)`, `submit(password)`, `cancel()`, signals `requested()`, `finished()`.
- `Wallpapers`, `Calculator`, `Spectrum` (`cava` 4-band wave when `activeConsumers > 0 && Media.playing`), `Theme`.

## IPC & Verification
```sh
./scripts/run.sh                                                        # run with low-memory glibc tunables
qs -p .                                                                 # run directly (requires Wayland)
qs ipc --pid <PID> call island toggle                                   # toggle compact <-> dashboard
qs ipc --pid <PID> call island open <key>                               # open panel on specific instance
qs ipc --pid <PID> call island liveStart id label icon 0.5              # start external Live Activity task
qs ipc --pid <PID> call island liveProgress id 0.8 label                # update task progress
qs ipc --pid <PID> call island liveDone id true                         # finish task (auto-clears after 3s)
grim -g "X,Y WxH" out.png                                               # capture screenshot
```
When testing in automated runs, wrap `qs -p .` with `timeout` so background instances are not left behind, and target the test instance with `--pid`.
