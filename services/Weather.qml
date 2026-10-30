pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Сервис погоды (Open-Meteo, локация и прогноз с локальным кешированием).
Singleton {
    id: root

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ukishima/weather"

    property bool ready: false
    property real temp: NaN
    property real feelsLike: NaN
    property int humidity: 0
    property real wind: 0
    property int code: 0
    property bool isDay: true
    property string icon: "cloud"
    property string desc: "Загрузка..."
    property string city: "Ижевск"
    property real lat: 56.85225
    property real lon: 53.19862

    property var hourly: []   // [{ time: "22:00", temp: 2, icon: "..." }]
    property var daily: []    // [{ day: "Ср", min: -1, max: 4, icon: "...", desc: "..." }]

    function codeInfo(c, day) {
        if (c === 0) return { icon: day ? "sunny" : "clear_night", desc: "Ясно" };
        if (c === 1 || c === 2) return { icon: day ? "partly_cloudy_day" : "partly_cloudy_night", desc: "Малооблачно" };
        if (c === 3) return { icon: "cloud", desc: "Пасмурно" };
        if (c === 45 || c === 48) return { icon: "foggy", desc: "Туман" };
        if (c >= 51 && c <= 57) return { icon: "grain", desc: "Морось" };
        if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return { icon: "rainy", desc: "Дождь" };
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return { icon: "weather_snowy", desc: "Снег" };
        if (c >= 95) return { icon: "thunderstorm", desc: "Гроза" };
        return { icon: "cloud", desc: "Облачно" };
    }

    function refresh() {
        if (fetchProc.running) return;
        fetchProc.running = false;
        fetchProc.running = true;
    }

    function loadLocCache() {
        try {
            const raw = locCacheFile.text();
            if (!raw || !raw.trim()) return;
            const loc = JSON.parse(raw);
            if (loc.lat && loc.lon) {
                root.lat = Number(loc.lat);
                root.lon = Number(loc.lon);
                if (loc.city) root.city = loc.city;
            }
        } catch (e) {}
    }

    function loadWeatherCache() {
        try {
            const raw = weatherCacheFile.text();
            if (!raw || !raw.trim()) return;
            const c = JSON.parse(raw);
            if (c && typeof c.temp === "number") {
                root.temp = c.temp;
                root.feelsLike = c.feelsLike !== undefined ? c.feelsLike : c.temp;
                root.humidity = c.humidity || 0;
                root.wind = c.wind || 0;
                root.code = c.code || 0;
                root.isDay = c.isDay !== false;
                const info = root.codeInfo(root.code, root.isDay);
                root.icon = info.icon;
                root.desc = info.desc;
                if (c.hourly && c.hourly.length) root.hourly = c.hourly;
                if (c.daily && c.daily.length) root.daily = c.daily;
                root.ready = true;
            } else if (c && typeof c.tempNow === "number") {
                // Совместимость со старым кешем ukishima
                root.temp = c.tempNow;
                root.feelsLike = c.tempNow;
                root.humidity = c.humidity || 0;
                root.code = c.codeNow || 0;
                root.isDay = c.isDay !== false;
                const info = root.codeInfo(root.code, root.isDay);
                root.icon = info.icon;
                root.desc = info.desc;
                root.ready = true;
            }
        } catch (e) {}
    }

    function saveCache() {
        const data = {
            temp: root.temp,
            feelsLike: root.feelsLike,
            humidity: root.humidity,
            wind: root.wind,
            code: root.code,
            isDay: root.isDay,
            hourly: root.hourly,
            daily: root.daily,
            ts: Date.now()
        };
        const json = JSON.stringify(data);
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "sh", root.cacheDir, json, root.cacheDir + "/weather-cache.json"]);
    }

    FileView {
        id: locCacheFile
        path: root.cacheDir + "/weather-loc.json"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: weatherCacheFile
        path: root.cacheDir + "/weather-cache.json"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        loadLocCache();
        loadWeatherCache();
        refresh();
    }

    Process {
        id: fetchProc
        command: [
            "curl", "-s", "--max-time", "8",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
            + "&hourly=temperature_2m,weather_code,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&timezone=auto&forecast_days=7"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                let success = false;
                if (raw) {
                    try {
                        const d = JSON.parse(raw);
                        if (d.current) {
                            root.temp = d.current.temperature_2m;
                            root.feelsLike = d.current.apparent_temperature;
                            root.humidity = d.current.relative_humidity_2m;
                            root.wind = d.current.wind_speed_10m;
                            root.code = d.current.weather_code;
                            root.isDay = d.current.is_day === 1;
                            const info = root.codeInfo(root.code, root.isDay);
                            root.icon = info.icon;
                            root.desc = info.desc;

                            // Почасовой (следующие 12 часов)
                            if (d.hourly && d.hourly.time) {
                                const nowIso = d.current.time || "";
                                let startIdx = 0;
                                for (let i = 0; i < d.hourly.time.length; i++) {
                                    if (d.hourly.time[i] >= nowIso) { startIdx = i; break; }
                                }
                                const hrs = [];
                                for (let i = startIdx; i < Math.min(startIdx + 7, d.hourly.time.length); i++) {
                                    const tStr = d.hourly.time[i].split("T")[1] || "00:00";
                                    const hi = root.codeInfo(d.hourly.weather_code[i], d.hourly.is_day ? d.hourly.is_day[i] === 1 : true);
                                    hrs.push({
                                        time: i === startIdx ? "Сейчас" : tStr.slice(0, 5),
                                        temp: Math.round(d.hourly.temperature_2m[i]),
                                        icon: hi.icon
                                    });
                                }
                                root.hourly = hrs;
                            }

                            // На 7 дней
                            if (d.daily && d.daily.time) {
                                const days = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"];
                                const dlist = [];
                                for (let i = 0; i < Math.min(7, d.daily.time.length); i++) {
                                    const dt = new Date(d.daily.time[i] + "T12:00:00");
                                    const di = root.codeInfo(d.daily.weather_code[i], true);
                                    dlist.push({
                                        day: i === 0 ? "Сегодня" : days[dt.getDay()],
                                        min: Math.round(d.daily.temperature_2m_min[i]),
                                        max: Math.round(d.daily.temperature_2m_max[i]),
                                        icon: di.icon,
                                        desc: di.desc
                                    });
                                }
                                root.daily = dlist;
                            }

                            root.ready = true;
                            root.saveCache();
                            success = true;
                        }
                    } catch (e) {}
                }

                if (!success) {
                    retryTimer.start();
                } else {
                    retryTimer.stop();
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                retryTimer.start();
            }
        }
    }

    // Быстрый повтор при отсутствии сети на старте системы (каждые 5 сек до успеха)
    Timer {
        id: retryTimer
        interval: 5000
        repeat: true
        running: false
        onTriggered: {
            root.refresh();
        }
    }

    // Регулярное обновление раз в 15 минут
    Timer {
        interval: 900000 // 15 мин
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
