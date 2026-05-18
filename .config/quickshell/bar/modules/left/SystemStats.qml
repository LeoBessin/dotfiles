// left/SystemStats.qml — CPU % + RAM used/total
// Click opens btop in kitty.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

BarWidget {
    id: root

    // ── State ─────────────────────────────────────────────────────────────
    property real cpuPercent: 0
    property real ramUsedGb:  0
    property real ramTotalGb: 0

    // Raw /proc/stat values from previous poll for delta calculation
    property var  _prevStat: null

    // ── Poll timer (every 2 s) ────────────────────────────────────────────
    Timer {
        interval:   2000
        running:    true
        repeat:     true
        triggeredOnStart: true
        onTriggered: { cpuProc.running = true; memProc.running = true }
    }

    // ── CPU — read /proc/stat ─────────────────────────────────────────────
    Process {
        id: cpuProc
        command: ["bash", "-c", "head -1 /proc/stat"]

        stdout: SplitParser {
            onRead: (line) => {
                // cpu  user nice system idle iowait irq softirq steal guest guest_nice
                const parts = line.trim().split(/\s+/)
                if (parts.length < 5) return
                const user    = parseInt(parts[1])
                const nice    = parseInt(parts[2])
                const system  = parseInt(parts[3])
                const idle    = parseInt(parts[4])
                const iowait  = parseInt(parts[5]) || 0
                const irq     = parseInt(parts[6]) || 0
                const softirq = parseInt(parts[7]) || 0
                const steal   = parseInt(parts[8]) || 0

                const totalIdle = idle + iowait
                const totalBusy = user + nice + system + irq + softirq + steal
                const total     = totalIdle + totalBusy

                if (root._prevStat !== null) {
                    const dTotal = total     - root._prevStat.total
                    const dIdle  = totalIdle - root._prevStat.idle
                    if (dTotal > 0)
                        root.cpuPercent = Math.round((1 - dIdle / dTotal) * 100)
                }
                root._prevStat = { total: total, idle: totalIdle }
            }
        }
    }

    // ── RAM — read /proc/meminfo ──────────────────────────────────────────
    Process {
        id: memProc
        command: ["bash", "-c", "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]

        stdout: SplitParser {
            onRead: (line) => {
                const m = line.match(/^(MemTotal|MemAvailable):\s+(\d+)/)
                if (!m) return
                const kb = parseInt(m[2])
                if (m[1] === "MemTotal")     root.ramTotalGb = kb / 1048576
                if (m[1] === "MemAvailable") root.ramUsedGb  = root.ramTotalGb - (kb / 1048576)
            }
        }
    }

    // ── Click → btop ──────────────────────────────────────────────────────
    onClicked: btopProc.running = true

    Process {
        id: btopProc
        command: ["kitty", "--title", "btop", "-e", "btop"]
    }

    // ── Content ───────────────────────────────────────────────────────────
    content: RowLayout {
        spacing: 6

        // CPU
        RowLayout {
            spacing: 3

            Text {
                text:  "\ue322"   // Material Symbols: memory / cpu chip
                font.family:  Theme.iconFamily
                font.pixelSize: Theme.iconSize
                color: root.hovered ? Theme.accent : Theme.fgDim
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            Text {
                text:  root.cpuPercent + "%"
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: root.cpuPercent > 80 ? Theme.red
                     : root.cpuPercent > 50 ? Theme.yellow
                     : Theme.fg
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
        }

        // Divider
        Rectangle {
            width:  1
            height: 14
            color:  Qt.rgba(1, 1, 1, 0.12)
        }

        // RAM
        RowLayout {
            spacing: 3

            Text {
                text:  "\ue322"   // ram icon placeholder — same chip glyph works
                font.family:  Theme.iconFamily
                font.pixelSize: Theme.iconSize
                color: root.hovered ? Theme.accent : Theme.fgDim
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            Text {
                text:  root.ramUsedGb.toFixed(1) + "G"
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: (root.ramUsedGb / (root.ramTotalGb || 1)) > 0.85 ? Theme.red
                     : (root.ramUsedGb / (root.ramTotalGb || 1)) > 0.65 ? Theme.yellow
                     : Theme.fg
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
        }
    }
}
