// compositor/HyprlandBackend.qml — read-only Hyprland IPC.
//
// Loaded by CompositorService only when running under Hyprland. It supplies the
// two things no cross-compositor protocol exposes: which output has focus, and
// per-window geometry for the workspace-overview mini-map. Nothing here changes
// compositor state — workspace switching goes through Windowset.activate() and
// window focus through Toplevel.activate(), both protocol-based.
import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0; height: 0

    // Hyprland has no built-in workspace overview to defer to, so the shell uses
    // its own WorkspaceSwitcher here.
    readonly property bool hasOverview: false

    function toggleOverview() {}

    // ── Focused output ────────────────────────────────────────────────────
    property var _focusSink: null

    function focusedOutput(cb) {
        _focusSink = cb
        focusProc.running = false
        focusProc.running = true
    }

    Process {
        id: focusProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: focusOut
            onStreamFinished: {
                var sink = root._focusSink
                root._focusSink = null
                if (!sink) return
                var name = ""
                try {
                    var monitors = JSON.parse(focusOut.text)
                    for (var i = 0; i < monitors.length; i++) {
                        if (monitors[i].focused) { name = monitors[i].name; break }
                    }
                } catch (e) {
                    console.warn("HyprlandBackend: unparseable `hyprctl monitors -j` — " + e)
                }
                sink(name)
            }
        }
    }

    // ── Overview snapshot ─────────────────────────────────────────────────
    property var _overviewSink: null

    function queryOverview(cb) {
        _overviewSink = cb
        overviewProc.running = false
        overviewProc.running = true
    }

    Process {
        id: overviewProc
        // One subprocess emitting one JSON document: cheaper than three calls and
        // it removes the jq dependency the old per-field pipelines had.
        command: ["bash", "-c",
            "printf '{\"monitors\":%s,\"workspaces\":%s,\"clients\":%s}' " +
            "\"$(hyprctl monitors -j)\" \"$(hyprctl workspaces -j)\" \"$(hyprctl clients -j)\""
        ]
        stdout: StdioCollector {
            id: overviewOut
            onStreamFinished: {
                var sink = root._overviewSink
                root._overviewSink = null
                if (sink) sink(root._parseOverview(overviewOut.text))
            }
        }
    }

    function _parseOverview(text) {
        var raw
        try {
            raw = JSON.parse(text)
        } catch (e) {
            console.warn("HyprlandBackend: unparseable hyprctl output — " + e)
            return { focusedOutput: "", workspaces: [] }
        }

        // Monitor geometry by name. hyprctl reports the mode in physical pixels
        // while window geometry is logical, so divide by scale (and swap on a
        // quarter-turn transform) to get the coordinate space windows live in.
        var monitors = raw.monitors || []
        var monByName = {}
        var focusedOutput = ""
        for (var i = 0; i < monitors.length; i++) {
            var m = monitors[i]
            var scale = m.scale || 1
            var lw = m.width / scale
            var lh = m.height / scale
            if (m.transform === 1 || m.transform === 3 || m.transform === 5 || m.transform === 7) {
                var t = lw; lw = lh; lh = t
            }
            monByName[m.name] = { x: m.x || 0, y: m.y || 0, w: lw, h: lh }
            if (m.focused) focusedOutput = m.name
        }

        var workspaces = raw.workspaces || []
        var entries = []
        var byName = {}
        for (var j = 0; j < workspaces.length; j++) {
            var ws = workspaces[j]
            var mon = monByName[ws.monitor] || { x: 0, y: 0, w: 1920, h: 1080 }
            var entry = {
                name:    String(ws.name),
                output:  ws.monitor || "",
                label:   ws.lastwindowtitle || "",
                monitor: { w: mon.w, h: mon.h },
                windows: []
            }
            entry._mon = mon
            byName[entry.name] = entry
            entries.push(entry)
        }

        // Clients carry global coordinates; the overview draws one monitor at a
        // time, so translate into monitor-local space and drop windows whose
        // centre lands outside it (scratchpads, windows parked off-screen).
        var clients = raw.clients || []
        for (var k = 0; k < clients.length; k++) {
            var c = clients[k]
            if (!c.workspace || !c.at || !c.size) continue
            var target = byName[String(c.workspace.name)]
            if (!target) continue

            var relX = c.at[0] - target._mon.x
            var relY = c.at[1] - target._mon.y
            var cw = c.size[0]
            var ch = c.size[1]
            if (relX + cw / 2 < 0 || relX + cw / 2 > target._mon.w) continue
            if (relY + ch / 2 < 0 || relY + ch / 2 > target._mon.h) continue

            target.windows.push({
                title: c.title || "",
                cls:   c["class"] || "",
                x: relX, y: relY, w: cw, h: ch
            })
        }

        for (var n = 0; n < entries.length; n++) delete entries[n]._mon
        return { focusedOutput: focusedOutput, workspaces: entries }
    }
}
