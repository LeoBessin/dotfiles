// right/Updates.qml — pending update count (pacman + AUR + flatpak)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

BarWidget {
    id: root

    visible: true

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
                text: `Pacman: ${UpdateService.pacmanCount}   AUR: ${UpdateService.aurCount}   Flatpak: ${UpdateService.flatpakCount}`
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color:          Theme.fg
            }
        }
    }

    // ── Click → kitty running yay + flatpak update ───────────────────────
    onClicked:      upgradeProc.running = true
    onRightClicked: UpdateService.runCheck()

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
            implicitWidth:  UpdateService.checking ? 13 : badgeLabel.implicitWidth + 6
            implicitHeight: 13
            radius:         6
            color: UpdateService.checking
                ? Theme.yellow
                : (UpdateService.totalCount > 0 ? Theme.accent : Theme.green)

            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Item {
                id: iconWrapper
                width:  13
                height: 13
                anchors.centerIn: parent

                Text {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: UpdateService.checking
                        ? "󰑓"
                        : (UpdateService.totalCount > 0 ? UpdateService.totalCount : "")
                    font.family: (UpdateService.checking || UpdateService.totalCount === 0)
                        ? Theme.iconFamily : Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 3
                    font.weight:    Font.Bold
                    color:          Theme.bgSolid
                }

                RotationAnimator on rotation {
                    running:  UpdateService.checking
                    from:     0
                    to:       360
                    duration: 1000
                    loops:    Animation.Infinite
                    onStopped: iconWrapper.rotation = 0
                }
            }
        }
    }
}
