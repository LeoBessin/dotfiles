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
        var next = []
        if (raw && raw.trim() !== "") {
            try {
                var json = JSON.parse(raw)
                if (Array.isArray(json.lockCommand))
                    next = json.lockCommand
            } catch (e) {
                console.warn("Config: ignoring malformed " + root.path + " — " + e)
            }
        }
        root.lockCommand = next
    }
}
