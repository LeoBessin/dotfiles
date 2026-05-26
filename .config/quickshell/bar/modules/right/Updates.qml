// right/Updates.qml — pending update count (pacman + AUR + flatpak)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

BarWidget {
    id: root

    property int totalCount:   0
    property int pacmanCount:  0
    property int aurCount:     0
    property int flatpakCount: 0

    visible: true

    Timer {
        interval:         1800000
        running:          true
        repeat:           true
        triggeredOnStart: true
        onTriggered: checkProc.running = true
    }

    // Outputs "pacman aur flatpak" counts on one line
    Process {
        id: checkProc
        command: ["sh", "-c",
            "p=$(checkupdates 2>/dev/null | wc -l); " +
            "a=$(yay -Qua 2>/dev/null | wc -l); " +
            "f=$(flatpak remote-ls --updates 2>/dev/null | wc -l); " +
            "echo \"$p $a $f\""
        ]
        stdout: SplitParser {
            onRead: (line) => {
                var parts = line.trim().split(/\s+/)
                root.pacmanCount  = parseInt(parts[0]) || 0
                root.aurCount     = parseInt(parts[1]) || 0
                root.flatpakCount = parseInt(parts[2]) || 0
                root.totalCount   = root.pacmanCount + root.aurCount + root.flatpakCount
            }
        }
    }

    // ── Tooltip — per-source breakdown ───────────────────────────────────
    PopupWindow {
        id: tooltip
        visible:        root.hovered
        anchor.item:    root
        anchor.edges:   Edges.Bottom
        anchor.gravity: Edges.Bottom

        implicitWidth:  tooltipLabel.implicitWidth + 16
        implicitHeight: tooltipLabel.implicitHeight + 12
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color:        Theme.bgPopup
            radius:       Theme.pillRadius
            border.color: Qt.rgba(0.70, 0.62, 0.86, 0.25)
            border.width: 1

            Text {
                id: tooltipLabel
                anchors.centerIn: parent
                text: `Pacman: ${root.pacmanCount}   AUR: ${root.aurCount}   Flatpak: ${root.flatpakCount}`
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color:          Theme.fg
            }
        }
    }

    // ── Click → kitty running yay + flatpak update ───────────────────────
    onClicked: upgradeProc.running = true

    Process {
        id: upgradeProc
        command: ["kitty", "sh", "-c",
            "fastfetch; yay && flatpak update; echo; echo '--- Done. Press Enter to close ---'; read"
        ]
    }

    // ── Content ───────────────────────────────────────────────────────────
    content: RowLayout {
        spacing: 2

        Text {
            text:           "󰮯"
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize - 2
            color: root.hovered ? Theme.accent : Theme.fg
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Rectangle {
            implicitWidth:  badgeLabel.implicitWidth + 6
            implicitHeight: 13
            radius:         6
            color:          totalCount > 0 ? Theme.accent : Theme.green

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text:           totalCount > 0 ? root.totalCount : ""
                font.family:    totalCount > 0 ? Theme.fontFamily : Theme.iconFamily
                font.pixelSize: Theme.fontSize - 3
                font.weight:    Font.Bold
                color:          Theme.bgSolid
            }
        }
    }
}
