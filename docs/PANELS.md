# How Island Panels Work

## Structure
- `shell.qml` → `Island.qml` (one window per monitor). Island renders the notch, the top strip, and underneath it **a single opened panel**.
- `services/*.qml` — singletons (`pragma Singleton`, root `Singleton {}`), import with `import qs.services`.
- `components/*.qml` — shared components, import with `import qs.components`.
- `panels/<Key>Panel.qml` — panels. Key → file: `launcher` → `panels/LauncherPanel.qml`, `clipboard` → `ClipboardPanel.qml`, etc.

## Panel Contract
```qml
import QtQuick
import qs.services
import qs.components

Item {
    id: root
    property var host: null          // Island: host.closePanel(), host.collapse(), host.openPanel("key")
    property bool wantsKeyboard: false  // true → panel receives forceActiveFocus() after loading
    implicitHeight: ...              // REQUIRED. Width is set by the host (≈ 830px at s=1.15). Keep height ≤ Theme.px(460).
}
```
- A panel is loaded via `Loader` only when open, so perform heavy work (Process, scanning) upon load or on demand. Keep persistent state in services.
- Esc is handled by the host (closes the panel). If the panel handles Esc itself (e.g. exiting an editor) — set `event.accepted = true`.
- The window grabs keyboard input (`WlrKeyboardFocus.OnDemand` + `HyprlandFocusGrab`) while the notch is expanded.
- Clicking outside the notch collapses it. After launching an app or copying content, call `host.collapse()`.

## Style
- All dimensions via `Theme.px(N)` (global scale `Theme.s`). No bare pixels.
- Font is `Theme.fontFamily`, icons use `Icon { name: "<material symbol>" }` (Material Symbols Rounded font, ligatures by name).
- Colors: `Theme.text/text2/text3`, cards `Theme.card` (hover `Theme.cardHover`), card radius `Theme.px(18..22)`, accents `Theme.blue/green/orange/red/pink/purple/accent`.
- Animations: `Behavior on x { Spring {} }` — iOS spring. Press — scale 0.85–0.9, hover — `Theme.cardHover`.
- Shared components: `Icon`, `Bar` (progress bar / slider: `value`, `tint`, `interactive`, `moved(v)` signal), `Spring`, `MorphView`, `StatTile`, `MediaCard`, `VolumeCard`, `Workspaces`, `StripButton`, `Caret` (smooth text insertion point in iOS/macOS style).
- Interface text should be clean and consistent.

## Service Contracts Island Relies On
Do not rename these properties — the notch depends on them for live activities and badges:
- `Notifs`: `list`, `unread`, `dnd`, signal `popup(n)`, `markRead()`, `dismiss(n)`, `clear()`, `invoke(n, actionId)`.
  Item: `{ id, appName, appIcon, image, summary, body, time, urgency, actions: [{id,text}] }`.
- `Weather`: `ready`, `temp`, `icon` (Material Symbol), `desc`, `city`, `refresh()`.
- `Apps`: `pins` (DesktopEntry array), `launch(entry)`.
- `Timers`: `running`, `mode` ("timer"|"stopwatch"), `display` (text "4:59"), signal `finished()`.
- `Recorder`: `recording`, `elapsed`, `elapsedText`, `stop()`.

## Verification
```sh
qs -p .                                                                 # run (requires BypassSandbox — Wayland)
qs ipc --pid <PID> call island open <key>                               # open panel on specific instance
grim -g "X,Y WxH" out.png                                               # screenshot
```
Run your instance with `timeout` so background processes are not left behind, and target it using `--pid`.
