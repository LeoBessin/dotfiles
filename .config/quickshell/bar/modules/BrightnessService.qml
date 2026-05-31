pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property int  current: 0
    property int  maximum: 100
    property real percent: maximum > 0 ? (current / maximum) * 100 : 0

    function setPercent(pct) {
        pct = Math.max(5, Math.min(100, pct))
        setBrightness.command = ["brightnessctl", "set", pct + "%"]
        setBrightness.running = true
        root.current = Math.round((pct / 100) * root.maximum)
    }

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

    Process {
        id: setBrightness
        command: ["brightnessctl", "set", "100%"]
        onExited: getCurrent.running = true
    }
}
