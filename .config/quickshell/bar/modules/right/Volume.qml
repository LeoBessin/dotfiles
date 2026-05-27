// right/Volume.qml — default sink volume + mute via wpctl/pactl
// Scroll to change volume, click to toggle mute, right-click to open pavucontrol.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

BarWidget {
    id: root

    function volumeIcon() {
        if (VolumeService.muted || VolumeService.volume === 0) return ""
        if (VolumeService.volume < 30)                         return ""
        if (VolumeService.volume < 70)                         return ""
        return ""
    }

    onClicked:      VolumeService.toggleMute()
    onRightClicked: pavucontrol.running = true
    onScrolled: (delta) => VolumeService.setVolume(delta)

    Process {
        id: pavucontrol
        command: ["pavucontrol", "-t", "3"]
        running: false
    }

    content: RowLayout {
        spacing: 4

        Text {
            text:           root.volumeIcon()
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize
            color: VolumeService.muted ? Theme.fgDim
                 : root.hovered        ? Theme.accent
                 : Theme.fg
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            text:           VolumeService.muted ? "mute" : VolumeService.volume + "%"
            font.family:    Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color:          VolumeService.muted ? Theme.fgDim : Theme.fg
        }
    }
}
