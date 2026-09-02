// Windowed dev harness for LockContent — NOT the lock screen.
//
//   qs -p ~/.config/quickshell/lock/preview.qml
//
// Renders the same LockContent the real lock uses, on one screen, as an
// ordinary layer surface that takes no keyboard focus. Cycles through the
// visual states so they can be inspected (or screenshotted) without engaging
// ext-session-lock and risking a lockout.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "modules"

ShellRoot {
    id: root

    property string wallpaper: ""
    property int    stage: 0

    readonly property var stages: [
        { dots: 0, busy: false, msg: "",                   err: false, caps: false },
        { dots: 6, busy: false, msg: "",                   err: false, caps: false },
        { dots: 8, busy: false, msg: "",                   err: false, caps: true  },
        { dots: 0, busy: true,  msg: "",                   err: false, caps: false },
        { dots: 0, busy: false, msg: "Incorrect password", err: true,  caps: false }
    ]
    readonly property var s: stages[stage]

    PanelWindow {
        // Pinned so screenshots are deterministic on a multi-output setup.
        // Override with QS_PREVIEW_OUTPUT=HDMI-A-1.
        screen: {
            const want = Quickshell.env("QS_PREVIEW_OUTPUT") || "eDP-1"
            for (const s of Quickshell.screens) if (s.name === want) return s
            return null
        }
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"

        LockContent {
            anchors.fill: parent
            wallpaper: root.wallpaper
            dotCount: root.s.dots
            busy: root.s.busy
            message: root.s.msg
            messageIsError: root.s.err
            capsOn: root.s.caps
            username: Quickshell.env("USER") ?? ""
            shakeTrigger: 0
        }
    }

    Timer {
        interval: 1200
        running: true
        repeat: true
        onTriggered: root.stage = (root.stage + 1) % root.stages.length
    }

    Process {
        running: true
        command: ["sh", "-c", "cat \"$HOME/.local/share/wallpapers/.current\" 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: (line) => {
                const p = line.trim()
                if (p !== "") root.wallpaper = "file://" + p
            }
        }
    }
}
