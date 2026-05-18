// right/Volume.qml — default sink volume + mute via wpctl/pactl
// Scroll to change volume, click to toggle mute, right-click to open pavucontrol.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

BarWidget {
    id: root

    property real volume: 0
    property bool muted: false

    function refresh() {
        volumeFetcher.running = false
        volumeFetcher.running = true
    }

    function volumeIcon() {
        if (root.muted || root.volume === 0) return ""
        if (root.volume < 30)               return ""
        if (root.volume < 70)               return ""
        return ""
    }

    Component.onCompleted: refresh()

    // Read current volume from wpctl
    Process {
        id: volumeFetcher
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: (line) => {
                var m = line.match(/Volume:\s*([\d.]+)(\s+\[MUTED\])?/)
                if (m) {
                    root.volume = Math.round(parseFloat(m[1]) * 100)
                    root.muted = !!m[2]
                }
            }
        }
    }

    // Watch for sink/server changes (covers volume, mute, and default-sink switches)
    Process {
        id: pactlSubscribe
        command: ["bash", "-c", "pactl subscribe | grep --line-buffered -E \"'(change|new|remove)' on (sink|server)\""]
        running: true
        stdout: SplitParser {
            onRead: (_) => root.refresh()
        }
    }

    onClicked: {
        muteToggle.running = false
        muteToggle.running = true
    }

    Process {
        id: muteToggle
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onRunningChanged: if (!running) root.refresh()
    }

    onRightClicked: {
        pavucontrol.running = true
    }

    Process {
        id: pavucontrol
        command: ["pavucontrol", "-t", "3"]
        running: false
    }

    onScrolled: (delta) => {
        volumeSet.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@",
                             (delta > 0 ? "5%+" : "5%-")]
        volumeSet.running = false
        volumeSet.running = true
    }

    Process {
        id: volumeSet
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"]
        onRunningChanged: if (!running) root.refresh()
    }

    content: RowLayout {
        spacing: 4

        Text {
            text:  root.volumeIcon()
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize
            color: root.muted ? Theme.fgDim
                 : root.hovered ? Theme.accent
                 : Theme.fg
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            text:  root.muted ? "mute" : root.volume + "%"
            font.family:    Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: root.muted ? Theme.fgDim : Theme.fg
        }
    }
}
