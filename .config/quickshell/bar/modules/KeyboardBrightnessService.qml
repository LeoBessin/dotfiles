pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property int current: 0
    property int maximum: 3

    function setLevel(level) {
        level = Math.max(0, Math.min(root.maximum, level))
        setKbdBrightness.command = ["brightnessctl", "-d", "asus::kbd_backlight", "set", String(level)]
        setKbdBrightness.running = false
        setKbdBrightness.running = true
        root.current = level
    }

    Component.onCompleted: {
        getKbdCurrent.running = true
        getKbdMax.running     = true
    }

    Process {
        id: getKbdCurrent
        command: ["brightnessctl", "-d", "asus::kbd_backlight", "get"]
        stdout: SplitParser {
            onRead: (line) => { root.current = parseInt(line.trim()) || 0 }
        }
    }

    Process {
        id: getKbdMax
        command: ["brightnessctl", "-d", "asus::kbd_backlight", "max"]
        stdout: SplitParser {
            onRead: (line) => { root.maximum = parseInt(line.trim()) || 3 }
        }
    }

    Process {
        id: setKbdBrightness
        command: ["brightnessctl", "-d", "asus::kbd_backlight", "set", "0"]
        onExited: getKbdCurrent.running = true
    }
}
