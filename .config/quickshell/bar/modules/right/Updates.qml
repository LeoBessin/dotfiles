// right/Updates.qml — pending update count badge; click runs hyde-shell system.update.sh
// Counts: hyde-shell system.update (polled every 30 minutes)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

BarWidget {
    id: root

    property int    totalCount:  0
    property string tooltipText: ""

    // Always visible
    visible: true

    // ── Poll every 30 minutes + on start ─────────────────────────────────
    Timer {
        interval:         1800000    // 30 minutes
        running:          true
        repeat:           true
        triggeredOnStart: true
        onTriggered: checkProc.running = true
    }

    // hyde-shell system.update — check for available updates
    Process {
        id: checkProc
        command: ["hyde-shell", "system.update"]
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    var obj = JSON.parse(line.trim())
                    var m = obj.text ? obj.text.match(/\d+/) : null
                    root.totalCount = m ? parseInt(m[0]) : 0
                    root.tooltipText = obj.tooltip ? obj.tooltip.replace(/\\n/g, "\n") : ""
                } catch (e) {
                    var n = parseInt(line.trim())
                    root.totalCount = isNaN(n) ? 0 : n
                }
            }
        }
    }

    // ── Tooltip ───────────────────────────────────────────────────────────
    PopupWindow {
        id: tooltip
        visible:        root.hovered && root.tooltipText !== ""
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
                text:           root.tooltipText
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color:          Theme.fg
                lineHeight:     1.4
            }
        }
    }

    // ── Click → hyde-shell system.update.sh up ───────────────────────────
    onClicked: upgradeProc.running = true

    Process {
        id: upgradeProc
        command: ["hyde-shell", "system.update.sh", "up"]
    }

    // ── Content ───────────────────────────────────────────────────────────
    content: RowLayout {
        id: countRow
        spacing: 2

        Text {
            text:  "󰮯"
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize - 2
            color: root.hovered ? Theme.accent : Theme.fg
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        // Badge pill — count or checkmark
        Rectangle {
            implicitWidth:  badgeLabel.implicitWidth + 6
            implicitHeight: 13
            radius:         6
            color:          totalCount > 0 ? Theme.accent : Theme.green

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text:  totalCount > 0 ? root.totalCount : "\ue876"
                font.family:    totalCount > 0 ? Theme.fontFamily : Theme.iconFamily
                font.pixelSize: Theme.fontSize - 3
                font.weight:    Font.Bold
                color: Theme.bgSolid
            }
        }
    }
}
