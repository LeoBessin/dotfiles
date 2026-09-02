// left/DockerWidget.qml — Portainer shortcut
// Left click opens Portainer (localhost:9001). Nothing else — no service
// state, no start/stop, no auth.
//
// The open goes through a script because `xdg-open` on its own cannot raise
// the browser: a process spawned from the bar has no XDG_ACTIVATION_TOKEN, so
// niri denies the focus request and the tab opens in the background.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

BarWidget {
    id: root

    onClicked: {
        openProc.running = false
        openProc.running = true
    }

    Process {
        id: openProc
        command: ["/home/nexus/.config/quickshell/bar/scripts/open_portainer.sh"]
    }

    content: RowLayout {
        spacing: 3

        Text {
            text: ""   // nf-linux-docker — the real Docker whale
            font.family:    Theme.nerdFamily
            font.pixelSize: Theme.iconSize - 3
            verticalAlignment: Text.AlignVCenter
            color: root.hovered ? Theme.accent : Theme.fgDim
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }
}
