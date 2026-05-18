// right/Microphone.qml — Pipewire default source mute toggle
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import ".."

BarWidget {
    id: root

    property var source: Pipewire.defaultSource
    property bool muted: source && source.audio ? source.audio.muted : false

    onClicked: {
        if (source && source.audio)
            source.audio.muted = !source.audio.muted
    }

    onRightClicked: {
        pavucontrolSource.running = true
    }

    Process {
        id: pavucontrolSource
        command: ["pavucontrol", "-t", "4"]
        running: false
    }

    content: RowLayout {
        spacing: 4

        Text {
            text:  root.muted ? "\ue02b" : "\ue029"
            // \ue02b = mic_off, \ue029 = mic
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize
            color: root.muted  ? Theme.red
                 : root.hovered ? Theme.accent
                 : Theme.fg
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        // Small status dot
        Rectangle {
            width:  6; height: 6
            radius: 3
            color:  root.muted ? Theme.red : Theme.green
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }
}
