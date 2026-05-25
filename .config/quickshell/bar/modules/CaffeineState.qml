pragma Singleton
import QtQuick

QtObject {
    id: root

    property bool active: false
    property int  durationMinutes: -1   // -1 = indefinite
    property int  remainingSeconds: 0
    property double endTime: 0          // ms epoch when timed mode expires

    // ── Countdown timer ───────────────────────────────────────────────────
    property Timer _countdown: Timer {
        interval: 1000
        running:  root.active && root.durationMinutes > 0
        repeat:   true
        onTriggered: {
            var left = Math.max(0, Math.round((root.endTime - Date.now()) / 1000))
            root.remainingSeconds = left
            if (left <= 0) root.deactivate()
        }
    }

    // ── Public API ────────────────────────────────────────────────────────
    function activateFor(minutes) {
        durationMinutes  = minutes
        endTime          = Date.now() + minutes * 60000
        remainingSeconds = minutes * 60
        active           = true
    }

    function activateIndefinite() {
        durationMinutes  = -1
        remainingSeconds = 0
        endTime          = 0
        active           = true
    }

    function deactivate() {
        active           = false
        durationMinutes  = -1
        remainingSeconds = 0
        endTime          = 0
    }

    // Formatted "mm:ss" for display in the pill
    readonly property string remainingLabel: {
        if (!active || durationMinutes < 0) return ""
        var m = Math.floor(remainingSeconds / 60)
        var s = remainingSeconds % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }
}
