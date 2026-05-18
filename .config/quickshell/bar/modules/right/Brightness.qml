// right/Brightness.qml — backlight control via brightnessctl
// Scroll to change, click to toggle between 30% and 100%.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

BarWidget {
    id: root

    property int current: 0
    property int maximum: 100
    property real percent: maximum > 0 ? (current / maximum) * 100 : 0

    function brightnessIcon() {
        if (percent < 25)  return "\ue1ac"   // brightness_low
        if (percent < 60)  return "\ue1ad"   // brightness_medium
        return "\ue1ae"                       // brightness_high
    }

    // ── Read current brightness on load ──────────────────────────────────
    Component.onCompleted: {
        getCurrent.running = true
        getMax.running     = true
    }

    Process {
        id: getCurrent
        command: ["brightnessctl", "get"]
        stdout: SplitParser {
            onRead: (line) => { root.current = parseInt(line.trim()) || 0 }
        }
    }

    Process {
        id: getMax
        command: ["brightnessctl", "max"]
        stdout: SplitParser {
            onRead: (line) => { root.maximum = parseInt(line.trim()) || 100 }
        }
    }

    // ── Set brightness helper ─────────────────────────────────────────────
    function setPercent(pct) {
        pct = Math.max(5, Math.min(100, pct))
        setBrightness.command = ["brightnessctl", "set", pct + "%"]
        setBrightness.running = true
        root.current = Math.round((pct / 100) * root.maximum)
    }

    Process {
        id: setBrightness
        command: ["brightnessctl", "set", "100%"]
        onExited: getCurrent.running = true
    }

    // ── Interactions ──────────────────────────────────────────────────────
    onClicked: {
        // Toggle 30% ↔ 100%
        setPercent(root.percent > 50 ? 30 : 100)
    }

    onScrolled: (delta) => {
        var step = 5
        setPercent(Math.round(root.percent) + (delta > 0 ? step : -step))
    }

    // ── Content ───────────────────────────────────────────────────────────
    content: RowLayout {
        spacing: 4

        Text {
            text:  root.brightnessIcon()
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize
            color: root.hovered ? Theme.accent : Theme.fgDim
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            text:  Math.round(root.percent) + "%"
            font.family:    Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fg
        }
    }
}
