pragma Singleton
import QtQuick
import Quickshell.Io
import "."

Item {
    id: root
    visible: false
    width: 0; height: 0

    property string status:        "unknown"   // active | inactive | failed | unknown
    readonly property bool running: status === "active"
    property bool starting:       false
    property bool stopping:       false

    property bool   authenticating: false
    property string authError:      ""
    property string pendingAction:  ""   // "start" | "stop" | ""

    function checkStatus() {
        statusProc.running = false
        statusProc.running = true
    }

    function requestStart() {
        pendingAction = "start"
        starting      = true
        beginAuth()
    }

    function requestStop() {
        pendingAction = "stop"
        stopping      = true
        beginAuth()
    }

    // sudo is already wired to try face recognition (howdy) first, falling
    // back to the normal password prompt via PAM — `-k` forces a fresh
    // check every time instead of reusing a cached sudo ticket. The
    // start/stop itself runs inside this SAME sudo call (rather than a
    // separate `sudo -v` + a second `sudo systemctl ...`) because sudo's
    // cached ticket isn't reliably shared across the separate processes
    // Quickshell spawns for each — a split validate-then-act flow silently
    // no-ops the second call.
    function beginAuth() {
        authError         = ""
        authenticating    = true
        authProc.running  = false
        authProc.command  = ["sudo", "-k", "-S", "systemctl", pendingAction, "docker"]
        authProc.stdinEnabled = true
        authProc.running  = true
    }

    function cancelAuth() {
        authProc.running = false
        authenticating   = false
        authError        = ""
        starting         = false
        stopping         = false
        pendingAction    = ""
    }

    function submitPassword(pw) {
        authProc.write(pw + "\n")
    }

    Process {
        id: authProc
        stdinEnabled: true
        onExited: (code) => {
            root.authenticating = false
            root.starting       = false
            root.stopping       = false
            if (code === 0) {
                root.authError = ""
                root.checkStatus()
            } else {
                root.authError = "Authentication failed — try again"
            }
            root.pendingAction = ""
        }
    }

    Process {
        id: statusProc
        command: ["systemctl", "is-active", "docker"]
        stdout: StdioCollector {
            id: statusCollector
            onStreamFinished: root.status = statusCollector.text.trim() || "unknown"
        }
    }

    Timer {
        interval:         Theme.dockerPollMs
        running:          true
        repeat:           true
        triggeredOnStart: true
        onTriggered: root.checkStatus()
    }
}
