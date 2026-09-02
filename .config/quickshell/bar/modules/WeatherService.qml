// WeatherService.qml — data behind the notification-center weather card.
//
// One request to Open-Meteo (no API key, no account) returns current, hourly and
// daily data together, so a refresh is a single ~4 KB GET. Coordinates come from
// config.json when set, otherwise from a one-off IP lookup; both the location and
// the last good payload are cached to disk so the card is populated instantly on
// restart and keeps showing last-known values while offline.
//
// Timestamps from the API are wall-clock strings for the *forecast* location
// ("2026-09-02T08:00", no offset), which is not necessarily this machine's
// timezone. Never hand them to Date.parse directly — go through _apiMs(), which
// applies the utc_offset_seconds the API reports alongside them. Display labels
// are sliced straight out of the string, so they read in the location's own time.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    visible: false
    width: 0; height: 0

    // ── Public state ──────────────────────────────────────────────────────
    property bool   ready:     false   // true once any data (cache or live) is applied
    property bool   loading:   false
    property string errorText: ""
    property real   lastFetch: 0       // ms epoch of the last successful fetch

    // Bumped by the heartbeat so `stale` re-evaluates without a binding on Date.now().
    property real   nowMs: Date.now()
    readonly property bool stale: ready && (nowMs - lastFetch) > Theme.weatherStaleMs

    property real   latitude:     0
    property real   longitude:    0
    property string locationName: ""

    property real   temp:         0
    property real   apparentTemp: 0
    property int    code:         0
    property bool   isDay:        true
    property real   humidity:     0
    property real   windSpeed:    0
    property real   todayMax:     0
    property real   todayMin:     0

    // Roles are fixed at first append and never vary afterwards — a ListModel
    // locks its schema on the first append, and a later object with a different
    // key set silently loses those roles.
    //   hourlyModel: { label, code, isDay, temp, kind }   kind ∈ "hour" | "sun"
    //   dailyModel:  { label, code, minTemp, maxTemp }
    property ListModel hourlyModel: ListModel {}
    property ListModel dailyModel:  ListModel {}

    // Normalisation range for the daily range bars, over the displayed rows only.
    property real weekMin: 0
    property real weekMax: 0

    readonly property bool imperial: Config.weatherUnits === "imperial"

    // ── Internals ─────────────────────────────────────────────────────────
    readonly property string _cachePath:
        Quickshell.env("HOME") + "/.local/share/quickshell/weather.json"

    property bool _locationKnown: false
    property real _geoResolvedAt: 0
    property real _utcOffset:     0     // seconds, from the API
    property var  _raw:           null  // last good payload, re-serialised into the cache
    property bool _started:       false
    property bool _parseOk:       false
    property bool _geoOk:         false
    property real _retryMs:       Theme.weatherRetryBaseMs
    property real _lastTick:      Date.now()
    property int  _lastDay:       new Date().getDate()

    // ── Public API ────────────────────────────────────────────────────────
    function refresh() {
        _ensureLocation()
    }

    // Called when the notification center opens: only spends a request when the
    // data on screen is actually old, mirroring the Claude/Copilot usage caches.
    function refreshIfStale() {
        if (!ready || (Date.now() - lastFetch) > Theme.weatherStaleMs) refresh()
    }

    // ── Condition mapping (WMO weather codes) ─────────────────────────────
    // Glyph names verified present in the installed Material Symbols Rounded
    // build; clear_night / cloudy / location_on are absent from it, hence
    // nightlight and cloud below.
    function codeIcon(c, day) {
        switch (c) {
        // Code 1 is "Mostly Clear", so it takes the clear glyph — Material has no
        // mostly-clear variant, and the cloud-forward partly_cloudy glyph reads as
        // a contradiction next to the label.
        case 0:
        case 1:  return day ? "\uf157" : "\uef5e"   // clear_day / nightlight
        case 2:  return day ? "\uf172" : "\uea46"   // partly_cloudy_day / _night
        case 3:  return "\ue2bd"                    // cloud
        case 45:
        case 48: return "\ue818"                    // foggy
        case 51:
        case 53:
        case 55:
        case 80: return "\uf61e"                    // rainy_light
        case 61:
        case 63:
        case 81: return "\uf176"                    // rainy
        case 65:
        case 82: return "\uf61f"                    // rainy_heavy
        case 56:
        case 57:
        case 66:
        case 67: return "\uf61d"                    // rainy_snow
        case 71:
        case 73:
        case 75:
        case 85:
        case 86: return "\ue2cd"                    // weather_snowy
        case 77: return "\ueb3b"                    // ac_unit
        case 95: return "\uebdb"                    // thunderstorm
        case 96:
        case 99: return "\uf67f"                    // weather_hail
        default: return "\ue2bd"                    // cloud
        }
    }

    readonly property string sunIcon:     "\ue1c6"   // wb_twilight
    readonly property string offlineIcon: "\ue2c1"   // cloud_off
    readonly property string refreshIcon: "\ue5d5"   // refresh

    function codeLabel(c) {
        switch (c) {
        case 0:  return "Clear"
        case 1:  return "Mostly Clear"
        case 2:  return "Partly Cloudy"
        case 3:  return "Cloudy"
        case 45: return "Fog"
        case 48: return "Freezing Fog"
        case 51: return "Light Drizzle"
        case 53: return "Drizzle"
        case 55: return "Heavy Drizzle"
        case 56:
        case 57: return "Freezing Drizzle"
        case 61: return "Light Rain"
        case 63: return "Rain"
        case 65: return "Heavy Rain"
        case 66:
        case 67: return "Freezing Rain"
        case 71: return "Light Snow"
        case 73: return "Snow"
        case 75: return "Heavy Snow"
        case 77: return "Snow Grains"
        case 80: return "Light Showers"
        case 81: return "Showers"
        case 82: return "Heavy Showers"
        case 85: return "Snow Showers"
        case 86: return "Heavy Snow Showers"
        case 95: return "Thunderstorm"
        case 96:
        case 99: return "Thunderstorm & Hail"
        default: return "—"
        }
    }

    // Linear interpolation along Theme.weatherRamp. Fahrenheit converts to °C
    // first so the ramp stops need no unit variant.
    function tempColor(v) {
        var ramp = Theme.weatherRamp
        var c    = imperial ? (v - 32) * 5 / 9 : v
        if (c <= ramp[0].t) return ramp[0].c
        for (var i = 1; i < ramp.length; i++) {
            if (c <= ramp[i].t) {
                var f = (c - ramp[i - 1].t) / (ramp[i].t - ramp[i - 1].t)
                var a = Qt.color(ramp[i - 1].c)
                var b = Qt.color(ramp[i].c)
                return Qt.rgba(a.r + (b.r - a.r) * f,
                               a.g + (b.g - a.g) * f,
                               a.b + (b.b - a.b) * f, 1)
            }
        }
        return ramp[ramp.length - 1].c
    }

    // ── Location ──────────────────────────────────────────────────────────
    function _applyConfigLocation() {
        if (!Config.weatherFixedLocation) return false
        var changed = (latitude !== Config.weatherLatitude)
                   || (longitude !== Config.weatherLongitude)
        latitude       = Config.weatherLatitude
        longitude      = Config.weatherLongitude
        locationName   = Config.weatherLocationName
        _locationKnown = true
        return changed
    }

    // A refresh only re-resolves the location when the cached one has aged past
    // the TTL; normally it goes straight to the forecast request.
    function _ensureLocation() {
        if (Config.weatherFixedLocation) {
            _applyConfigLocation()
            _fetchWeather()
            return
        }
        if (_locationKnown && (Date.now() - _geoResolvedAt) < Theme.weatherGeoTtlMs) {
            _fetchWeather()
            return
        }
        _resolveLocation()
    }

    function _resolveLocation() {
        if (geoProc.running) return
        // ip-api.com's free tier is HTTP-only. Setting weatherLatitude /
        // weatherLongitude in config.json skips this call entirely.
        _geoOk  = false
        loading = true
        geoProc.running = false
        geoProc.running = true
    }

    Process {
        id: geoProc
        command: ["sh", "-c",
            "curl -sfS -m 8 'http://ip-api.com/json/?fields=status,city,lat,lon'"]
        // waitForEnd holds `exited` back until the stream is drained, so the
        // branch below always sees the parsed result.
        onExited: (exitCode, exitStatus) => {
            if (root._geoOk) root._fetchWeather()
            else             root._onFailure("location lookup failed")
        }
        stdout: StdioCollector {
            id: geoCollector
            waitForEnd: true
            onStreamFinished: {
                try {
                    var j = JSON.parse(geoCollector.text)
                    if (j.status === "success") {
                        root.latitude       = j.lat
                        root.longitude      = j.lon
                        root.locationName   = j.city || ""
                        root._locationKnown = true
                        root._geoResolvedAt = Date.now()
                        root._geoOk         = true
                        root._saveCache()          // keep the location even if the forecast fails
                    }
                } catch (e) {
                    console.warn("WeatherService: unparseable location response — " + e)
                }
            }
        }
    }

    // ── Weather fetch ─────────────────────────────────────────────────────
    function _url() {
        var unit = imperial
                 ? "&temperature_unit=fahrenheit&wind_speed_unit=mph"
                 : ""
        return "https://api.open-meteo.com/v1/forecast"
             + "?latitude="  + latitude.toFixed(4)
             + "&longitude=" + longitude.toFixed(4)
             + "&current=temperature_2m,apparent_temperature,weather_code,is_day,"
             + "relative_humidity_2m,wind_speed_10m"
             + "&hourly=temperature_2m,weather_code,is_day"
             + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset"
             + "&timezone=auto&forecast_days=6&forecast_hours=12"
             + unit
    }

    // Several things legitimately ask for a fetch at once on startup — the cache
    // load, the fallback timer and config arriving late. Re-assigning `running`
    // on a live Process kills it, which surfaces as a spurious failure and a
    // pointless backoff, so an in-flight request is left alone unless the caller
    // explicitly forces a replacement.
    function _fetchWeather(force) {
        if (!_locationKnown) { _resolveLocation(); return }
        if (weatherProc.running && !force) return
        loading  = true
        _parseOk = false
        weatherProc.running = false
        weatherProc.command = ["sh", "-c", "curl -sfS -m 12 \"" + _url() + "\""]
        weatherProc.running = true
    }

    Process {
        id: weatherProc
        onExited: (exitCode, exitStatus) => {
            if (root._parseOk) root._onSuccess()
            else               root._onFailure("forecast fetch failed")
        }
        stdout: StdioCollector {
            id: weatherCollector
            waitForEnd: true
            onStreamFinished: {
                var txt = weatherCollector.text
                if (!txt || txt.trim() === "") return
                try {
                    var d = JSON.parse(txt)
                    if (root._applyData(d)) {
                        root._raw     = d
                        root._parseOk = true
                    }
                } catch (e) {
                    console.warn("WeatherService: unparseable forecast response — " + e)
                }
            }
        }
    }

    function _onSuccess() {
        loading    = false
        errorText  = ""
        lastFetch  = Date.now()
        nowMs      = lastFetch
        _retryMs   = Theme.weatherRetryBaseMs
        retryTimer.stop()
        _saveCache()
    }

    function _onFailure(why) {
        loading   = false
        errorText = why
        // Back off 30 s → 1 m → 2 m → 5 m, capped at the normal poll cadence, so
        // a laptop that is simply offline stops retrying every half minute.
        retryTimer.interval = Math.min(_retryMs, Theme.weatherPollMs)
        retryTimer.restart()
        _retryMs = Math.min(_retryMs * 2, Theme.weatherPollMs)
    }

    Timer {
        id: retryTimer
        repeat: false
        onTriggered: root._ensureLocation()
    }

    // ── Parsing ───────────────────────────────────────────────────────────
    // API wall-clock string → real epoch ms, via the offset the API reports.
    function _apiMs(s) {
        return Date.parse(s + "Z") - root._utcOffset * 1000
    }

    function _applyData(d) {
        if (!d || !d.current || !d.hourly || !d.daily) return false

        _utcOffset   = d.utc_offset_seconds || 0
        temp         = d.current.temperature_2m
        apparentTemp = d.current.apparent_temperature
        code         = d.current.weather_code
        isDay        = d.current.is_day === 1
        humidity     = d.current.relative_humidity_2m
        windSpeed    = d.current.wind_speed_10m
        todayMax     = d.daily.temperature_2m_max[0]
        todayMin     = d.daily.temperature_2m_min[0]

        _buildHourly(d)
        _buildDaily(d)
        ready = true
        return true
    }

    // The next sunrise or sunset after `after`, as a strip slot.
    function _nextSunEvent(d, after) {
        var events = []
        for (var i = 0; i < d.daily.time.length; i++) {
            events.push(d.daily.sunrise[i])
            events.push(d.daily.sunset[i])
        }
        events.sort()
        for (var j = 0; j < events.length; j++) {
            var t = _apiMs(events[j])
            if (t > after) return { t: t, label: events[j].slice(11, 16) }
        }
        return null
    }

    function _buildHourly(d) {
        var times = d.hourly.time
        var temps = d.hourly.temperature_2m
        var codes = d.hourly.weather_code
        var days  = d.hourly.is_day
        var now   = Date.now()

        // "Now" always leads, using the current reading rather than the hour bucket.
        var slots = [{ t: now, label: "Now", code: code, isDay: isDay ? 1 : 0,
                       temp: Math.round(temp), kind: "hour" }]

        for (var i = 0; i < times.length; i++) {
            var t = _apiMs(times[i])
            if (t <= now) continue
            slots.push({ t: t, label: times[i].slice(11, 13), code: codes[i],
                         isDay: days[i], temp: Math.round(temps[i]), kind: "hour" })
        }

        // Apple's widget threads the next sunrise/sunset in among the hours; the
        // temperature shown is the neighbouring hour's.
        var sun = _nextSunEvent(d, now)
        if (sun) {
            for (var j = 1; j < slots.length; j++) {
                if (slots[j].t > sun.t) {
                    slots.splice(j, 0, { t: sun.t, label: sun.label, code: 0,
                                         isDay: slots[j].isDay,
                                         temp: slots[j - 1].temp, kind: "sun" })
                    break
                }
            }
        }

        hourlyModel.clear()
        var n = Math.min(Theme.weatherHourSlots, slots.length)
        for (var k = 0; k < n; k++) {
            // Append the fixed role set only — `t` stays out of the model.
            hourlyModel.append({ label: slots[k].label, code:  slots[k].code,
                                 isDay: slots[k].isDay, temp:  slots[k].temp,
                                 kind:  slots[k].kind })
        }
    }

    function _buildDaily(d) {
        var names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var rows  = []
        var mn    =  1e9
        var mx    = -1e9

        // Starts at tomorrow: today's high/low is already in the card header.
        for (var i = 1; i <= Theme.weatherDailyRows && i < d.daily.time.length; i++) {
            var p  = d.daily.time[i].split("-")
            // Built from the calendar parts rather than parsed, so the weekday is
            // the location's calendar day with no timezone or DST edge cases.
            var wd = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2])).getDay()
            // Rounded before the bounds are taken, because the bars are drawn
            // from the rounded values: mixing the two lets a max that rounds up
            // (26.5 → 27) push its bar past the right edge of the track.
            var lo = Math.round(d.daily.temperature_2m_min[i])
            var hi = Math.round(d.daily.temperature_2m_max[i])
            mn = Math.min(mn, lo)
            mx = Math.max(mx, hi)
            rows.push({ label: names[wd], code: d.daily.weather_code[i],
                        minTemp: lo, maxTemp: hi })
        }

        dailyModel.clear()
        for (var j = 0; j < rows.length; j++) dailyModel.append(rows[j])

        // Guard against a degenerate range collapsing every bar to zero width.
        if (mx - mn < 1) { mx = mn + 1 }
        weekMin = mn
        weekMax = mx
    }

    // ── Disk cache ────────────────────────────────────────────────────────
    FileView {
        id: cacheFile
        path: root._cachePath
        preload: true
        printErrors: false      // no cache on a first run is the normal case
        atomicWrites: true
        onLoaded:     { root._loadCache(cacheFile.text()); root._start() }
        onLoadFailed: root._start()
    }

    function _loadCache(raw) {
        if (!raw || raw.trim() === "") return
        try {
            var p = JSON.parse(raw)
            if (!Config.weatherFixedLocation
                && typeof p.lat === "number" && typeof p.lon === "number") {
                latitude       = p.lat
                longitude      = p.lon
                locationName   = p.name || ""
                _locationKnown = true
                _geoResolvedAt = p.geoAt || 0
            }
            if (p.data) {
                _raw = p.data
                // Applied before any request lands, so the card is never empty on
                // restart; `stale` marks it until a live fetch replaces it.
                if (_applyData(p.data)) lastFetch = p.fetchedAt || 0
            }
        } catch (e) {
            console.warn("WeatherService: ignoring malformed " + _cachePath + " — " + e)
        }
    }

    function _saveCache() {
        cacheFile.setText(JSON.stringify({
            lat:       latitude,
            lon:       longitude,
            name:      locationName,
            geoAt:     _geoResolvedAt,
            fetchedAt: lastFetch,
            data:      _raw
        }))
    }

    // ── Scheduling ────────────────────────────────────────────────────────
    function _start() {
        if (_started) return
        _started = true
        _applyConfigLocation()
        _ensureLocation()
    }

    Component.onCompleted: cacheDirProc.running = true

    // FileView.setText will not create the directory itself.
    Process {
        id: cacheDirProc
        command: ["sh", "-c", "mkdir -p \"$HOME/.local/share/quickshell\""]
    }

    // Neither FileView signal is guaranteed to arrive; this makes sure the first
    // fetch happens regardless.
    Timer {
        interval: 1500
        running:  true
        repeat:   false
        onTriggered: root._start()
    }

    Timer {
        interval:         Theme.weatherPollMs
        running:          true
        repeat:           true
        triggeredOnStart: false
        onTriggered:      root._ensureLocation()
    }

    // Heartbeat: refreshes `stale`, and catches the two cases a plain interval
    // timer misses — waking from suspend with hours-old data, and rolling past
    // midnight, which shifts what "tomorrow" means for the daily rows.
    Timer {
        interval: Theme.weatherHeartbeatMs
        running:  true
        repeat:   true
        onTriggered: {
            var now = Date.now()
            var gap = now - root._lastTick
            var day = new Date().getDate()
            root._lastTick = now
            root.nowMs     = now
            if (gap > Theme.weatherSuspendGapMs || day !== root._lastDay) {
                root._lastDay = day
                root._ensureLocation()
            }
        }
    }

    Connections {
        target: Config
        function onWeatherFixedLocationChanged() {
            if (root._applyConfigLocation()) root._fetchWeather()
            else if (!Config.weatherFixedLocation) root._ensureLocation()
        }
        function onWeatherUnitsChanged() { if (root._started) root._fetchWeather(true) }
    }
}
