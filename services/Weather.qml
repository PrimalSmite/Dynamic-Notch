pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Weather service (Open-Meteo, location and forecast with local caching).
Singleton {
    id: root

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/dynamic-notch/weather"

    property bool ready: false
    property real temp: NaN
    property real feelsLike: NaN
    property int humidity: 0
    property real wind: 0
    property int code: 0
    property bool isDay: true
    property string icon: "cloud"
    property color iconColor: "#FFD60A"
    property string desc: "Loading..."
    property string city: "London"
    property real lat: 51.5074
    property real lon: -0.1278

    property var hourly: []   // [{ time: "Now", temp: 2, icon: "...", iconColor: "..." }]
    property var daily: []    // [{ day: "Wed", min: -1, max: 4, icon: "...", iconColor: "...", desc: "..." }]

    property bool searchingCities: false
    property var searchResults: []
    property string _pendingQuery: ""

    readonly property var presetCities: [
        { name: "Izhevsk", sub: "Russia · Udmurtia", aliases: "ижевск izhevsk", lat: 56.8523, lon: 53.1986 },
        { name: "Moscow", sub: "Russia", aliases: "москва moscow", lat: 55.7558, lon: 37.6173 },
        { name: "Saint Petersburg", sub: "Russia", aliases: "санкт-петербург питер спб saint petersburg", lat: 59.9343, lon: 30.3351 },
        { name: "London", sub: "United Kingdom", aliases: "лондон london", lat: 51.5074, lon: -0.1278 },
        { name: "Tokyo", sub: "Japan", aliases: "токио tokyo", lat: 35.6762, lon: 139.6503 }
    ]

    function codeInfo(c, day) {
        if (c === 0) return { icon: day ? "sunny" : "clear_night", desc: "Sunny", color: day ? "#FFD60A" : "#A0C4FF" };
        if (c === 1 || c === 2) return { icon: day ? "partly_cloudy_day" : "partly_cloudy_night", desc: "Partly Cloudy", color: day ? "#FFD60A" : "#A0C4FF" };
        if (c === 3) return { icon: "cloud", desc: "Overcast", color: Qt.rgba(1, 1, 1, 0.65) };
        if (c === 45 || c === 48) return { icon: "foggy", desc: "Fog", color: Qt.rgba(1, 1, 1, 0.65) };
        if (c >= 51 && c <= 57) return { icon: "grain", desc: "Drizzle", color: "#0A84FF" };
        if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return { icon: "rainy", desc: "Rain", color: "#0A84FF" };
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return { icon: "weather_snowy", desc: "Snow", color: "#90CAF9" };
        if (c >= 95) return { icon: "thunderstorm", desc: "Thunderstorm", color: "#BF5AF2" };
        return { icon: "cloud", desc: "Cloudy", color: Qt.rgba(1, 1, 1, 0.65) };
    }

    // Calculates a representative daily weather code based on hourly data (rather than Open-Meteo worst-hour WMO)
    function representativeDailyCode(dayStr, hourlyData, dailyPrecip, dailySnow) {
        if (!hourlyData || !hourlyData.time || !hourlyData.weather_code) return 0;
        const dayIndices = [];
        for (let i = 0; i < hourlyData.time.length; i++) {
            if (hourlyData.time[i].indexOf(dayStr) === 0) dayIndices.push(i);
        }
        if (dayIndices.length === 0) return 0;

        let targetIndices = [];
        if (hourlyData.is_day) {
            for (let i = 0; i < dayIndices.length; i++) {
                const idx = dayIndices[i];
                if (hourlyData.is_day[idx] === 1) targetIndices.push(idx);
            }
        }
        if (targetIndices.length < 4) {
            targetIndices = [];
            for (let i = 0; i < dayIndices.length; i++) {
                const idx = dayIndices[i];
                const h = parseInt(hourlyData.time[idx].split("T")[1] || "12", 10);
                if (h >= 8 && h <= 19) targetIndices.push(idx);
            }
        }
        if (targetIndices.length === 0) targetIndices = dayIndices;

        const codes = targetIndices.map(idx => hourlyData.weather_code[idx]);
        const n = codes.length;

        if (codes.some(c => c >= 95)) return 95;

        let snowHours = 0;
        let rainHours = 0;
        let fogHours = 0;
        let clearHours = 0;
        let partlyHours = 0;
        let overcastHours = 0;

        for (let i = 0; i < n; i++) {
            const c = codes[i];
            if ((c >= 71 && c <= 77) || c === 85 || c === 86) snowHours++;
            else if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) rainHours++;
            else if (c === 45 || c === 48) fogHours++;
            else if (c === 0) clearHours++;
            else if (c === 1 || c === 2) partlyHours++;
            else if (c === 3) overcastHours++;
        }

        const pSum = typeof dailyPrecip === "number" ? dailyPrecip : 0;
        const sSum = typeof dailySnow === "number" ? dailySnow : 0;

        // Significant snow (only if accumulated and fell for a significant portion of day)
        if ((sSum >= 0.5 || (pSum >= 1.0 && snowHours >= 2)) && snowHours >= Math.ceil(n * 0.35)) {
            return sSum >= 3.0 ? 73 : 71;
        }
        // Significant rain
        if (pSum >= 1.0 && rainHours >= Math.ceil(n * 0.35)) {
            return pSum >= 5.0 ? 63 : 61;
        }
        // Dense fog during daytime
        if (fogHours > n / 2) return 45;

        // Dominant sky condition
        if (overcastHours >= partlyHours + clearHours) return 3;
        if (partlyHours >= clearHours) return 2;
        if (clearHours > 0) return 0;
        return 3;
    }

    function refresh() {
        fetchProc.running = false;
        fetchProc.running = true;
    }

    function setLocation(cityName, latVal, lonVal) {
        if (!cityName || isNaN(latVal) || isNaN(lonVal)) return;
        root.city = String(cityName);
        root.lat = Number(latVal);
        root.lon = Number(lonVal);
        const locData = JSON.stringify({
            city: root.city,
            lat: root.lat,
            lon: root.lon
        });
        Quickshell.execDetached([
            "sh", "-c",
            "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"",
            "sh", root.cacheDir, locData, root.cacheDir + "/weather-loc.json"
        ]);
        root.retryCount = 0;
        root.refresh();
    }

    function detectLocationByIp() {
        if (ipGeoProc.running) return;
        ipGeoProc.running = true;
    }

    function searchCities(query) {
        const q = (query || "").trim();
        if (q.length < 2) {
            root.searchResults = [];
            root.searchingCities = false;
            return;
        }
        root._pendingQuery = q;
        root.searchingCities = true;
        geoSearchProc.running = false;
        const isCyrillic = /[а-яё]/i.test(q);
        const lang = isCyrillic ? "ru" : "en";
        geoSearchProc.command = [
            "curl", "-s", "--max-time", "5", "-G",
            "https://geocoding-api.open-meteo.com/v1/search",
            "--data-urlencode", "name=" + q,
            "-d", "count=10&language=" + lang + "&format=json"
        ];
        geoSearchProc.running = true;
    }

    function loadLocCache() {
        try {
            const raw = locCacheFile.text();
            if (!raw || !raw.trim()) return;
            const loc = JSON.parse(raw);
            if (loc.lat !== undefined && loc.lon !== undefined) {
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
                root.iconColor = info.color;
                root.desc = info.desc;
                if (c.hourly && c.hourly.length) root.hourly = c.hourly;
                if (c.daily && c.daily.length) root.daily = c.daily;
                root.ready = true;
            } else if (c && typeof c.tempNow === "number") {
                // Compatibility with legacy cache format
                root.temp = c.tempNow;
                root.feelsLike = c.tempNow;
                root.humidity = c.humidity || 0;
                root.code = c.codeNow || 0;
                root.isDay = c.isDay !== false;
                const info = root.codeInfo(root.code, root.isDay);
                root.icon = info.icon;
                root.iconColor = info.color;
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
            + "&hourly=temperature_2m,weather_code,is_day,precipitation"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,snowfall_sum"
            + "&timezone=auto&forecast_days=7&wind_speed_unit=ms"
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
                            root.iconColor = info.color;
                            root.desc = info.desc;

                            // Hourly (slot "Now" + next 6 hours)
                            if (d.hourly && d.hourly.time) {
                                const hrs = [];
                                const currentRound = Math.round(root.temp) || 0;
                                hrs.push({
                                    time: "Now",
                                    temp: currentRound,
                                    icon: root.icon,
                                    iconColor: root.iconColor
                                });

                                const nowIso = d.current.time || "";
                                let startIdx = -1;
                                for (let i = 0; i < d.hourly.time.length; i++) {
                                    if (d.hourly.time[i] > nowIso) {
                                        startIdx = i;
                                        break;
                                    }
                                }

                                if (startIdx !== -1) {
                                    for (let i = startIdx; i < Math.min(startIdx + 6, d.hourly.time.length); i++) {
                                        const tStr = d.hourly.time[i].split("T")[1] || "00:00";
                                        const isDay = d.hourly.is_day ? d.hourly.is_day[i] === 1 : true;
                                        const hi = root.codeInfo(d.hourly.weather_code[i], isDay);
                                        const rTemp = Math.round(d.hourly.temperature_2m[i]) || 0;
                                        hrs.push({
                                            time: tStr.slice(0, 5),
                                            temp: rTemp,
                                            icon: hi.icon,
                                            iconColor: hi.color
                                        });
                                    }
                                }
                                root.hourly = hrs;
                            }

                            // 7-day forecast with representative daytime prediction
                            if (d.daily && d.daily.time) {
                                const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                                const dlist = [];
                                for (let i = 0; i < Math.min(7, d.daily.time.length); i++) {
                                    const dt = new Date(d.daily.time[i] + "T12:00:00");
                                    const pSum = d.daily.precipitation_sum ? d.daily.precipitation_sum[i] : 0;
                                    const sSum = d.daily.snowfall_sum ? d.daily.snowfall_sum[i] : 0;
                                    const repCode = root.representativeDailyCode(d.daily.time[i], d.hourly, pSum, sSum);
                                    const di = root.codeInfo(repCode, true);
                                    const rMin = Math.round(d.daily.temperature_2m_min[i]) || 0;
                                    const rMax = Math.round(d.daily.temperature_2m_max[i]) || 0;
                                    dlist.push({
                                        day: i === 0 ? "Today" : days[dt.getDay()],
                                        min: rMin,
                                        max: rMax,
                                        icon: di.icon,
                                        iconColor: di.color,
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
                    root.scheduleRetry();
                } else {
                    root.retryCount = 0;
                    retryTimer.stop();
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.scheduleRetry();
            }
        }
    }

    property int retryCount: 0
    readonly property int maxRetries: 5

    function scheduleRetry() {
        if (root.retryCount >= root.maxRetries) {
            retryTimer.stop();
            return;
        }
        root.retryCount++;
        retryTimer.interval = Math.min(60000, 5000 * Math.pow(2, root.retryCount - 1));
        retryTimer.restart();
    }

    // Exponential backoff retry on initial network failure (max 5 attempts)
    Timer {
        id: retryTimer
        interval: 5000
        repeat: false
        running: false
        onTriggered: {
            root.refresh();
        }
    }

    // Geocoding search via Open-Meteo
    Process {
        id: geoSearchProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.searchingCities = false;
                const raw = text.trim();
                if (!raw) {
                    root.searchResults = [];
                    return;
                }
                try {
                    const d = JSON.parse(raw);
                    const arr = d && d.results ? d.results : [];
                    const parsed = [];
                    for (let i = 0; i < arr.length; i++) {
                        const r = arr[i];
                        if (!r || !r.name || isNaN(r.latitude) || isNaN(r.longitude)) continue;
                        const parts = [];
                        if (r.country) parts.push(r.country);
                        if (r.admin1 && r.admin1 !== r.name) parts.push(r.admin1);
                        parsed.push({
                            name: r.name,
                            sub: parts.join(" · "),
                            lat: Number(r.latitude),
                            lon: Number(r.longitude)
                        });
                    }
                    root.searchResults = parsed;
                } catch (e) {
                    root.searchResults = [];
                }
            }
        }
        onExited: function(code) {
            if (code !== 0) root.searchingCities = false;
        }
    }

    // Automatic location detection by IP
    Process {
        id: ipGeoProc
        running: false
        command: ["curl", "-s", "--max-time", "5", "https://ipwho.is/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (!raw) return;
                try {
                    const d = JSON.parse(raw);
                    if (d && d.success !== false && d.city && !isNaN(d.latitude) && !isNaN(d.longitude)) {
                        root.setLocation(d.city, d.latitude, d.longitude);
                    }
                } catch (e) {}
            }
        }
    }

    // Regular update every 15 minutes
    Timer {
        interval: 900000 // 15 min
        running: true
        repeat: true
        onTriggered: {
            root.retryCount = 0;
            root.refresh();
        }
    }
}
