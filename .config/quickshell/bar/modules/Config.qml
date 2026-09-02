// Config.qml — optional user overrides from ~/.config/quickshell/bar/config.json
//
// The file is entirely optional: if it is missing or malformed, every value stays
// at its default and the shell behaves exactly as if this singleton did not exist.
// Defaults themselves live with their consumer (see CompositorService.lockCommand),
// so an empty value here means "use the built-in default", never "use nothing".
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0; height: 0

    readonly property string path: Quickshell.env("HOME") + "/.config/quickshell/bar/config.json"

    // Command run by the notification-center Lock button.
    // Empty → CompositorService picks a per-compositor default.
    property var lockCommand: []

    // Weather card location. Undefined → WeatherService falls back to an IP
    // lookup; set both to pin the location and skip that network call entirely.
    property var    weatherLatitude:     undefined
    property var    weatherLongitude:    undefined
    property string weatherLocationName: ""
    // "" or "metric" → °C / km-h. "imperial" → °F / mph.
    property string weatherUnits:        ""

    readonly property bool weatherFixedLocation:
        typeof weatherLatitude === "number" && typeof weatherLongitude === "number"

    FileView {
        id: configFile
        path: root.path
        watchChanges: true
        printErrors: false        // a missing config.json is the normal case
        // watchChanges only reports that the file changed; re-reading it is on us,
        // and that read is what emits textChanged.
        onFileChanged: configFile.reload()
        onTextChanged: root._parse(configFile.text())
    }

    function _parse(raw) {
        var next     = []
        var lat      = undefined
        var lon      = undefined
        var locName  = ""
        var units    = ""

        if (raw && raw.trim() !== "") {
            try {
                var json = JSON.parse(raw)
                if (Array.isArray(json.lockCommand))
                    next = json.lockCommand
                if (typeof json.weatherLatitude  === "number") lat = json.weatherLatitude
                if (typeof json.weatherLongitude === "number") lon = json.weatherLongitude
                if (typeof json.weatherLocationName === "string") locName = json.weatherLocationName
                if (typeof json.weatherUnits === "string")        units   = json.weatherUnits
            } catch (e) {
                console.warn("Config: ignoring malformed " + root.path + " — " + e)
            }
        }

        root.lockCommand = next
        // Coordinates only count as an override when both are present, so a
        // half-filled config falls back to the IP lookup instead of pinning 0,0.
        var paired = (lat !== undefined && lon !== undefined)
        root.weatherLatitude     = paired ? lat : undefined
        root.weatherLongitude    = paired ? lon : undefined
        root.weatherLocationName = locName
        root.weatherUnits        = units
    }
}
