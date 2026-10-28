# Как устроены панели острова

## Структура
- `shell.qml` → `Island.qml` (по окну на монитор). Island рисует чёлку, верхнюю строку (strip) и под ней **одну открытую панель**.
- `services/*.qml` — синглтоны (`pragma Singleton`, корень `Singleton {}`), импорт `import qs.services`.
- `components/*.qml` — общие компоненты, импорт `import qs.components`.
- `panels/<Key>Panel.qml` — панели. Ключ → файл: `launcher` → `panels/LauncherPanel.qml`, `clipboard` → `ClipboardPanel.qml` и т.д.

## Контракт панели
```qml
import QtQuick
import qs.services
import qs.components

Item {
    id: root
    property var host: null          // Island: host.closePanel(), host.collapse(), host.openPanel("key")
    property bool wantsKeyboard: false  // true → после загрузки панель получает forceActiveFocus()
    implicitHeight: ...              // ОБЯЗАТЕЛЬНО. Ширину задаёт хост (≈ 830px при s=1.15). Высоту держи ≤ Theme.px(460).
}
```
- Панель загружается через `Loader` только когда открыта, поэтому тяжёлую работу (Process, сканирование) делай при загрузке/по требованию. Постоянное состояние — в сервисах.
- Esc обрабатывает хост (закрывает панель). Если панель сама обрабатывает Esc (например, выход из редактора) — `event.accepted = true`.
- Окно получает клавиатуру (`WlrKeyboardFocus.OnDemand` + `HyprlandFocusGrab`), пока чёлка раскрыта.
- Клик мимо чёлки сворачивает её. После запуска приложения/копирования и т.п. вызывай `host.collapse()`.

## Стиль
- Все размеры — через `Theme.px(N)` (глобальный масштаб `Theme.s`). Никаких «голых» пикселей.
- Шрифт `Theme.fontFamily`, иконки — `Icon { name: "<material symbol>" }` (шрифт Material Symbols Rounded, лигатуры по имени).
- Цвета: `Theme.text/text2/text3`, карточки `Theme.card` (hover `Theme.cardHover`), радиус карточек `Theme.px(18..22)`, акценты `Theme.blue/green/orange/red/pink/purple/accent`.
- Анимации: `Behavior on x { Spring {} }` — пружина iOS. Нажатие — scale 0.85–0.9, hover — `Theme.cardHover`.
- Общие компоненты: `Icon`, `Bar` (полоска/слайдер: `value`, `tint`, `interactive`, сигнал `moved(v)`), `Spring`, `MorphView`, `StatTile`, `MediaCard`, `VolumeCard`, `Workspaces`, `StripButton`.
- Тексты интерфейса — на русском.

## Сервисы-контракты, которые читает Island
Не меняй имена этих свойств — на них завязана чёлка (живые активности, бейджи):
- `Notifs`: `list`, `unread`, `dnd`, сигнал `popup(n)`, `markRead()`, `dismiss(n)`, `clear()`, `invoke(n, actionId)`.
  Элемент: `{ id, appName, appIcon, image, summary, body, time, urgency, actions: [{id,text}] }`.
- `Weather`: `ready`, `temp`, `icon` (Material Symbol), `desc`, `city`, `refresh()`.
- `Apps`: `pins` (массив DesktopEntry), `launch(entry)`.
- `Timers`: `running`, `mode` ("timer"|"stopwatch"), `display` (текст "4:59"), сигнал `finished()`.
- `Recorder`: `recording`, `elapsed`, `elapsedText`, `stop()`.

## Проверка
```sh
qs -p /home/illidan/Documents/antigravity/lucid-chandrasekhar            # запустить (нужен BypassSandbox — Wayland)
qs ipc --pid <PID> call island open <key>                               # открыть панель у конкретного инстанса
grim -g "X,Y WxH" out.png                                               # скриншот
```
Запускай свой инстанс с `timeout`, чтобы не оставлять процессы, и выбирай его через `--pid`.
