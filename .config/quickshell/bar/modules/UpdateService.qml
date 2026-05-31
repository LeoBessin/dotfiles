pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property int  totalCount:   0
    property int  pacmanCount:  0
    property int  aurCount:     0
    property int  flatpakCount: 0
    property bool checking:     false

    function runCheck() {
        root.checking = true
        minDisplayTimer.restart()
        checkProc.running = true
    }

    // Keeps the checking indicator visible for at least 2s
    Timer {
        id: minDisplayTimer
        interval: 2000
        onTriggered: root.checking = false
    }

    Timer {
        interval:         1800000
        running:          true
        repeat:           true
        triggeredOnStart: true
        onTriggered: root.runCheck()
    }

    Process {
        id: checkProc
        command: ["sh", "-c",
            "p=$(checkupdates 2>/dev/null | wc -l); " +
            "a=$(yay -Qua 2>/dev/null | wc -l); " +
            "f=$(flatpak remote-ls --updates 2>/dev/null | wc -l); " +
            "echo \"$p $a $f\""
        ]
        onRunningChanged: if (!running) minDisplayTimer.restart()
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
}
