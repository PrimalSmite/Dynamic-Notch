# AGENTS.md — Dynamic Notch (Quickshell) Handoff Guide

This file provides complete context for AI coding agents and developers to start working on **Dynamic Notch** immediately.

---

## 1. Project Overview

**Dynamic Notch** is a Dynamic Island / Control Center shell for **Wayland (Hyprland)** built with QML/QtQuick on **[Quickshell](https://outfoxxed.me/quickshell/)**.

- **Target setup**: Stationary desktop PC running Hyprland (no laptop features such as battery, Wi-Fi, or Bluetooth widgets).
- **Language / Stack**: QML + JavaScript (`Quickshell`, `Quickshell.Wayland`, `Quickshell.Hyprland`, `Quickshell.Io`, `Quickshell.Services.*`) + lightweight POSIX shell scripts (`scripts/`).
- **Experimental subproject (`native/`)**: A standalone C++20 / Wayland Layer-Shell / OpenGL ES 3.0 prototype (`native/CMakeLists.txt`, `native/src/`) backed by `MockServices`. It is **not** the active desktop shell; do not confuse it with the Quickshell QML codebase unless explicitly asked to work on `native/`.

---

## 2. Repository Map

```text
.
├── shell.qml                   # Entrypoint (ShellRoot): wallpaper Background windows + Island Overlay windows per screen
├── Island.qml                  # Core window, state machine (compact/osd/dashboard/panel), focus grab, Live Wings, OSDs, panel Loader
├── services/                   # 19 QML singletons (pragma Singleton, import qs.services)
│   ├── Apps.qml                # DesktopEntries search, launch frequency scoring, pinned apps
│   ├── Audio.qml               # PipeWire default sink/source, volume/mute, mic privacy detection
│   ├── Auth.qml                # Polkit agent + FIFO askpass integration (scripts/sudo-askpass.sh)
│   ├── Calculator.qml          # Engineering math engine (trig, logs, factorials, history)
│   ├── Clipboard.qml           # cliphist watcher/history + thumbnail cache trigger
│   ├── IslandIpc.qml           # IpcHandler { target: "island" } for Hyprland keybinds & external scripts
│   ├── IslandPrefs.qml         # Persistent user settings (~/.config/dynamic-notch/preferences.json)
│   ├── Keyboard.qml            # Hyprland keyboard layout & Caps Lock sysfs polling
│   ├── LiveActivity.qml        # Priority queue for Live Wings + external IPC task slot
│   ├── Media.qml               # MPRIS player tracking, title/art cleanup, lazy progress polling
│   ├── Notifs.qml              # Notification daemon, DND, unread tracking, auto-read on focus
│   ├── Recorder.qml            # gpu-screen-recorder wrapper, countdown, region/screen, recent files
│   ├── Spectrum.qml            # Lazy 4-band cava audio spectrum (active only when visible & playing)
│   ├── SysInfo.qml             # /proc/stat & /proc/[pid]/stat deltas, mem, disk, temp, net, topProcs
│   ├── SysToggles.qml          # Night Light (hyprsunset), Keep Awake (systemd-inhibit), Game Mode, grim/slurp screenshots
│   ├── Theme.qml               # Design tokens: Theme.px(N), fonts, spring constants, colors
│   ├── Timers.qml              # Countdown timer + stopwatch with laps
│   ├── Wallpapers.qml          # Wallpaper directory scanner, active wallpaper state
│   └── Weather.qml             # Open-Meteo forecast, city geocoding, IP geolocation, cache
├── components/                 # 19 shared QML components (import qs.components)
│   ├── AudioWave.qml           # 4-band Spectrum visualizer
│   ├── Bar.qml                 # Progress bar / interactive slider (value, tint, interactive, moved(v))
│   ├── Caret.qml               # Smooth animated text caret
│   ├── DuoBubble.qml           # Detached circular secondary Live Activity bubble ("duo" mode)
│   ├── Icon.qml                # Material Symbols Rounded icon wrapper
│   ├── LiveSlotContent.qml     # Shared renderer for Live Activity slots (media, timer, recorder, mic, thermal, ipc, modes, muted)
│   ├── LiveWing.qml            # Left/right notch wing container
│   ├── MediaCard.qml           # Media player card
│   ├── MorphView.qml           # Animated view switcher
│   ├── NotchShape.qml          # Top-edge notch geometry with concave fillets
│   ├── ProgressRing.qml        # Vector circular progress ring
│   ├── RollingClock.qml        # Animated rolling digit clock
│   ├── Spring.qml              # iOS-style spring Behavior helper
│   ├── StatTile.qml            # System metric tile
│   ├── StripButton.qml         # Dashboard top-strip button
│   ├── TrackCard.qml           # Compact track info card
│   ├── VolumeCard.qml          # Audio volume/sink card
│   └── Workspaces.qml          # Hyprland workspace capsules
├── panels/                     # 15 lazy-loaded panels (panels/<Key>Panel.qml)
│   ├── LauncherPanel.qml       # App launcher + integrated calculator ("launcher", dock)
│   ├── NotificationsPanel.qml  # Notification center + DND ("notifications", dock)
│   ├── MixerPanel.qml          # Audio mixer & sink/source switcher ("mixer", dock)
│   ├── SysmonPanel.qml         # CPU/mem/net/process monitor ("sysmon", dock)
│   ├── RecorderPanel.qml       # Screen recorder controls & viewfinder ("recorder", dock)
│   ├── TimerPanel.qml          # Interactive ruler timer & stopwatch ("timer", dock)
│   ├── WallpaperPanel.qml      # Wallpaper carousel & folder selector ("wallpaper", dock)
│   ├── ClipboardPanel.qml      # cliphist text & image history ("clipboard", dock)
│   ├── NotesPanel.qml          # Markdown scratchpad notes ("notes", dock)
│   ├── SettingsPanel.qml       # 3-tab settings & control center ("settings", dock)
│   ├── PowerPanel.qml          # Lock/Suspend/Logout/Reboot/Poweroff ("power", dock)
│   ├── CalendarPanel.qml       # Month grid calendar ("calendar", contextual)
│   ├── WeatherPanel.qml        # Hourly/7-day weather & city search ("weather", contextual)
│   ├── MediaPanel.qml          # Full MPRIS controls ("media", contextual)
│   └── AuthPanel.qml           # Polkit / sudo askpass prompt ("auth", contextual)
├── scripts/
│   ├── run.sh                  # Low-memory launcher (MALLOC_ARENA_MAX=2, GLIBC_TUNABLES=glibc.malloc.hugetlb=0)
│   ├── cliphist-thumbs.sh      # Generates & prunes clipboard image thumbnails
│   ├── magick-policy/policy.xml# Strict ImageMagick decode sandbox policy for untrusted clipboard bytes
│   └── sudo-askpass.sh         # SUDO_ASKPASS FIFO bridge to IslandIpc.askpass
└── docs/
    └── PANELS.md               # Architecture, panel contract, and service contracts
```

---

## 3. Core Architecture & Critical Conventions

### State Machine (`Island.qml`)
`win.mode` is derived from state properties:
- `"panel"` when `panel !== ""`
- `"dashboard"` when `expanded === true`
- `"osd"` when `osd !== ""`
- `"compact"` otherwise

`win.notchHidden` hides the notch when `isGameActive && mode === "compact"` (fullscreen or game window detected via Hyprland `hasFullscreen` / window class / `"game"` tag, controlled by `IslandPrefs.hideInGames`).

### Wayland / Hyprland Focus & Window Geometry Rules
1. **Never bind `PanelWindow.implicitHeight` to animated notch height.** It must stay static (`modelData ? modelData.height : Theme.px(1080)`). Click-through is handled by `mask: Region`.
2. **Focus Grab Debounce:** `HyprlandFocusGrab` is armed via `grabArmTimer` (180ms) when switching to `WlrKeyboardFocus.Exclusive` to avoid false-positive `onCleared` collapses during focus handover. When a system tray menu opens (`win.trayMenuOpen`), focus drops to `WlrKeyboardFocus.OnDemand`.

### Panel Contract (`panels/<Key>Panel.qml`)
- Must expose `property var host: null` and `property bool wantsKeyboard: false`.
- Must define `implicitHeight` (keep `<= Theme.px(460)`). Width is controlled by `Island.qml`.
- Loaded lazily via `Loader` (`win.loadedPanel`). Perform heavy work on load/demand and store persistent state in `services/*.qml`.
- `Esc` is handled by `Island.qml` (collapses). `Backspace` / right-click returns to dashboard (`host.backToDashboard()`). To intercept `Esc` inside a panel (e.g. closing an inner modal), set `event.accepted = true`.

### Styling & Zero-Idle-CPU Rules
- **Scaling:** Always use `Theme.px(N)` (no raw pixel literals).
- **Fonts & Icons:** `Theme.fontFamily`, `Theme.monoFamily`, `Icon { name: "<material_symbol>" }`.
- **Physics:** Use `Spring {}` for motion and `Theme.card` / `Theme.cardHover` for surfaces.
- **Zero-Idle-CPU:** Heavy/continuous work (like `Spectrum.qml` spawning `cava`, or `Media.qml` position polling) uses an `activeConsumers` reference count so it consumes 0% CPU when no visible component needs it. Preserve this pattern.

### Persistence Paths
- Config: `~/.config/dynamic-notch/preferences.json` (`IslandPrefs`), `pins.json` (`Apps`).
- State: `~/.local/state/dynamic-notch/launcher-usage.json` (`Apps`), `notes/` (`NotesPanel`).
- Cache: `~/.cache/dynamic-notch/weather/` (`Weather`), `cliphist-thumbs/` (`Clipboard`).

---

## 4. IPC Reference (`IslandIpc.qml`)

Target name: `island` (`qs -p . ipc call island <command> [args...]`, or `qs ipc --pid <PID> call island ...`).

- **Navigation:** `toggle`, `close`, `open <panel>`, `media`, `mixer`, `nextPanel`, `prevPanel`
- **Audio & Media:** `volUp`, `volDown`, `mute`, `toggleMic`, `playPause`, `nextTrack`, `prevTrack`
- **System & Capture:** `dnd`, `record`, `refreshWeather`, `toggleKeepAwake`, `toggleNightLight`, `screenshotRegion`, `screenshotFull`, `screenshotTaken <mode>`
- **Auth:** `askpass <msg> <actionId> <replyFile>`
- **External Live Activity:** `liveStart <id> <label> <icon> <progress>`, `liveProgress <id> <progress> <label>`, `liveDone <id> <ok>`, `liveClear <id>`

---

## 5. Current Repository State at Handoff

- **Latest commit:** `66736ed` (`feat: ILA Track change in fullscreen`).
- **Uncommitted WIP changes in working tree** (do not discard without checking with the user):
  - `services/Media.qml`: added `property color trackAccent: "#5EEAD4"`.
  - `components/LiveSlotContent.qml`: animated media icon scale/opacity on play/pause, `AudioWave` colored with `Media.trackAccent`, pulsing opacity animation on paused timer.
  - `services/Audio.qml`: added `sinkName`, `sinkIcon`, and `volumeStepped` / `micMuteToggled` / `sinkSwitched` signals.
  - `services/Clipboard.qml`: added `lastKind`, `lastPreview`, `lastColorHex` metadata for richer clipboard OSDs.
  - `services/Recorder.qml`: added `recordingSaved(filePath, durationText)` signal and `lastSavedDuration` property.

---

## 6. Running, Testing & Verification

```bash
# Run in current Wayland/Hyprland session (low-memory wrapper)
./scripts/run.sh

# Or run with a timeout during automated verification so no orphan process remains
timeout 15s qs -p . &
PID=$!
sleep 2
qs ipc --pid "$PID" call island open settings
grim -g "X,Y WxH" /tmp/test.png
```

If modifying `native/` instead of the Quickshell QML files:
```bash
cmake -B native/build -S native && cmake --build native/build
```
