pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property real volume: 0
    property bool muted:  false

    function refresh() {
        volumeFetcher.running = false
        volumeFetcher.running = true
    }

    function toggleMute() {
        muteToggle.running = false
        muteToggle.running = true
    }

    function setVolume(delta) {
        volumeSet.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@",
                             (delta > 0 ? "5%+" : "5%-")]
        volumeSet.running = false
        volumeSet.running = true
    }

    Component.onCompleted: refresh()

    Process {
        id: volumeFetcher
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: (line) => {
                var m = line.match(/Volume:\s*([\d.]+)(\s+\[MUTED\])?/)
                if (m) {
                    root.volume = Math.round(parseFloat(m[1]) * 100)
                    root.muted  = !!m[2]
                }
            }
        }
    }

    Process {
        id: pactlSubscribe
        command: ["bash", "-c", "pactl subscribe | grep --line-buffered -E \"'(change|new|remove)' on (sink|server)\""]
        running: true
        stdout: SplitParser {
            onRead: (_) => root.refresh()
        }
    }

    Process {
        id: muteToggle
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onRunningChanged: if (!running) root.refresh()
    }

    Process {
        id: volumeSet
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"]
        onRunningChanged: if (!running) root.refresh()
    }
}
