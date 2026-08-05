// compositor/NiriBackend.qml — read-only niri IPC.
//
// Mirror of HyprlandBackend: same two functions, same return shapes, nothing that
// mutates compositor state. Workspace switching and window focus are handled by
// the shared protocol path in CompositorService, not here.
import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0; height: 0

    // ── Native workspace overview ─────────────────────────────────────────
    // niri has its own overview, and on niri it is strictly better than the
    // shell's: it draws real live window previews, which the shell cannot do here
    // because niri has no hyprland-toplevel-export-v1. So the shell defers to it.
    readonly property bool hasOverview: true

    function toggleOverview() {
        overviewToggle.running = false
        overviewToggle.running = true
    }

    Process {
        id: overviewToggle
        command: ["niri", "msg", "action", "toggle-overview"]
    }

    // ── Focused output ────────────────────────────────────────────────────
    property var _focusSink: null

    function focusedOutput(cb) {
        _focusSink = cb
        focusProc.running = false
        focusProc.running = true
    }

    Process {
        id: focusProc
        command: ["niri", "msg", "-j", "focused-output"]
        stdout: StdioCollector {
            id: focusOut
            onStreamFinished: {
                var sink = root._focusSink
                root._focusSink = null
                if (!sink) return
                var name = ""
                try {
                    // null when no output is connected
                    var output = JSON.parse(focusOut.text)
                    if (output && output.name) name = output.name
                } catch (e) {
                    console.warn("NiriBackend: unparseable `niri msg -j focused-output` — " + e)
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
        command: ["bash", "-c",
            "printf '{\"outputs\":%s,\"workspaces\":%s,\"windows\":%s}' " +
            "\"$(niri msg -j outputs)\" \"$(niri msg -j workspaces)\" \"$(niri msg -j windows)\""
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
            console.warn("NiriBackend: unparseable niri msg output — " + e)
            return { focusedOutput: "", workspaces: [] }
        }

        // `niri msg -j outputs` is a map keyed by output name, and its `logical`
        // block is already in logical pixels — no scale conversion needed.
        var outputs = raw.outputs || {}
        var sizeByOutput = {}
        for (var name in outputs) {
            var logical = outputs[name].logical
            if (logical) sizeByOutput[name] = { w: logical.width, h: logical.height }
        }

        var workspaces = raw.workspaces || []
        var entries = []
        var byId = {}
        var focusedOutput = ""
        for (var i = 0; i < workspaces.length; i++) {
            var ws = workspaces[i]
            var output = ws.output || ""
            if (ws.is_focused) focusedOutput = output
            var entry = {
                // Must match ext-workspace's name so CompositorService can pair the
                // two: niri sends the workspace name, or its 1-based index if unnamed.
                name:    ws.name ? String(ws.name) : String(ws.idx),
                output:  output,
                label:   "",
                monitor: sizeByOutput[output] || { w: 1920, h: 1080 },
                windows: []
            }
            entry._bestFocus = -1
            byId[ws.id] = entry
            entries.push(entry)
        }

        // Tile properties are the ones matching what a user calls "the window", and
        // tile_pos_in_workspace_view is already in the monitor-local space the
        // overview draws in — so it is used as-is when present.
        //
        // It is null for any window not in its workspace's current view, which is
        // every window on a non-active workspace. Those windows must still be
        // listed: focusToplevel() relies on this mapping to find which workspace
        // holds a window. Their position is approximated from the scrolling-layout
        // indices, which is only ever seen if the shell's own workspace switcher is
        // used on niri (by default it defers to niri's overview instead).
        var windows = raw.windows || []
        for (var j = 0; j < windows.length; j++) {
            var win = windows[j]
            var target = byId[win.workspace_id]
            if (!target) continue

            var layout = win.layout || {}
            var size = layout.tile_size || [target.monitor.w, target.monitor.h]
            var pos = layout.tile_pos_in_workspace_view
            if (!pos) {
                // pos_in_scrolling_layout is (column, tile-in-column), 1-based.
                var cell = layout.pos_in_scrolling_layout || [1, 1]
                pos = [(cell[0] - 1) * size[0], (cell[1] - 1) * size[1]]
            }

            var title = win.title || ""
            target.windows.push({
                title: title,
                cls:   win.app_id || "",
                x: pos[0], y: pos[1], w: size[0], h: size[1]
            })

            // niri has no per-workspace "last window" field; the most recently
            // focused window is the closest equivalent.
            var stamp = win.focus_timestamp
            var focusedAt = stamp ? (stamp.secs * 1e9 + stamp.nanos) : 0
            if (focusedAt > target._bestFocus) {
                target._bestFocus = focusedAt
                target.label = title
            }
        }

        for (var n = 0; n < entries.length; n++) delete entries[n]._bestFocus
        return { focusedOutput: focusedOutput, workspaces: entries }
    }
}
