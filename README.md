# Dynamic Notch (Quickshell)

Dynamic Notch and control center for Wayland (Hyprland), written in QML using [Quickshell](https://outfoxxed.me/quickshell/).

## Features

- **Compact "notch"**: status display, media player, notifications, and indicators.
- **Interactive panels**:
  - Application launcher with integrated calculator (`launcher`)
  - Clipboard history with image previews via `cliphist` (`clipboard`)
  - Notification center (`notifications`)
  - Volume control and audio sinks (`mixer`)
  - Resource and process monitor (`sysmon`)
  - Screen and region recording via `gpu-screen-recorder` (`recorder`)
  - Timer and stopwatch (`timer`)
  - Wallpaper gallery and switcher (`wallpaper`)
  - Quick Markdown notes (`notes`)
  - System toggles and settings (`settings`)
  - Power, sleep, and lock menu (`power`)
  - Weather (Open-Meteo) and calendar (`weather`, `calendar`)

## Dependencies

- **Core**:
  - `quickshell` (Wayland layer-shell)
  - `hyprland`
- **Utilities**:
  - `cliphist`, `wl-clipboard`, `imagemagick` (for clipboard)
  - `grim`, `slurp` (for screenshots and area selection)
  - `gpu-screen-recorder` (for screen recording)
  - `playerctl` (media control)
  - `pamixer` / PipeWire (volume control)
  - `brightnessctl` (brightness control)
  - `hyprpaper` (wallpaper management)
  - `notify-send` / `libnotify`
- **Fonts**:
  - *SF Pro Rounded* (or any system sans-serif font via `Theme.qml`)
  - *JetBrainsMono Nerd Font*
  - *Material Symbols Rounded*

## Running

### Manual Run
```bash
qs -p /path/to/dynamic-notch
```

### Autostart in Hyprland (`hyprland.conf`)
```ini
exec-once = qs -p ~/path/to/dynamic-notch
```

## Control via IPC

Opening and switching panels:
```bash
qs ipc call island open launcher
qs ipc call island open clipboard
qs ipc call island open mixer
qs ipc call island open power
```
Collapse panel:
```bash
qs ipc call island collapse
```

## Configuration

### Weather Location

By default, the weather service uses `London`. You can set your city and coordinates by creating a config file at:
`~/.cache/dynamic-notch/weather/weather-loc.json`

Example:
```json
{
  "city": "Tokyo",
  "lat": 35.6762,
  "lon": 139.6503
}
```
After saving, press `R` inside the weather panel to refresh the forecast.

## Project Structure

A detailed guide on panel architecture and component contracts can be found in [docs/PANELS.md](docs/PANELS.md).

