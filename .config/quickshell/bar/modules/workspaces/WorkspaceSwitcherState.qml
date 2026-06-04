pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root
    visible: false
    width: 0; height: 0

    property bool active:        false
    property var  targetScreen:  null
    property int  selectedIndex: 0
    property int  activeWsId:    -1

    // Per-workspace monitor bounds (global logical coords): {wsId: {x, y, w, h}}
    property var monitorByWs: ({})

    property var  workspaceIds:         []
    property var  windowsByWs:          ({})   // {wsId: [{title, cls, x, y, w, h}]}
    property var  lastWindowTitleByWs:  ({})   // {wsId: string}
    property bool loaded:               false
    property var  _rawWindows:          ({})

    function open(screen) {
        if (active) return
        targetScreen = screen
        _rawWindows  = {}
        windowsByWs  = {}
        loaded       = false

        // Snapshot all workspaces and build per-workspace monitor map
        var wss    = Hyprland.workspaces.values
        var ids    = []
        var monMap = {}
        for (var i = 0; i < wss.length; i++) {
            var ws = wss[i]
            if (ws.id <= 0) continue
            ids.push(ws.id)
            var mon = ws.monitor
            if (mon) {
                monMap[ws.id] = {
                    x: mon.x      || 0,
                    y: mon.y      || 0,
                    w: mon.width  || (screen ? screen.width  : 1920),
                    h: mon.height || (screen ? screen.height : 1080)
                }
            }
        }
        ids.sort(function(a, b) { return a - b })
        workspaceIds = ids
        monitorByWs  = monMap

        var fmon = Hyprland.focusedMonitor
        activeWsId = fmon ? fmon.activeWorkspace.id : -1

        var sel = 0
        for (var j = 0; j < ids.length; j++) {
            if (ids[j] === activeWsId) { sel = j; break }
        }
        selectedIndex = sel

        active = true

        wsLoader.running    = false
        wsLoader.running    = true
        clientLoader.running = false
        clientLoader.running = true
    }

    function close() {
        active       = false
        targetScreen = null
        loaded       = false
    }

    function confirm() {
        if (!active || workspaceIds.length === 0) return
        var wsId = workspaceIds[selectedIndex]
        if (wsId === undefined) return
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })")
        close()
    }

    Process {
        id: wsLoader
        command: ["bash", "-c",
            "hyprctl workspaces -j | jq -rc '.[] | \"\\(.id)|\\(.lastwindowtitle)\"'"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                var p = line.split("|")
                if (p.length < 2) return
                var wsId = parseInt(p[0])
                if (isNaN(wsId)) return
                var titles = root.lastWindowTitleByWs
                titles[wsId] = p.slice(1).join("|")   // rejoin in case title contains "|"
                root.lastWindowTitleByWs = titles
            }
        }
    }

    Process {
        id: clientLoader
        command: ["bash", "-c",
            "hyprctl clients -j | jq -rc '.[] | \"\\(.workspace.id)|\\(.title)|\\(.class)|\\(.at[0])|\\(.at[1])|\\(.size[0])|\\(.size[1])\"'"
        ]
        stdout: SplitParser {
            // Accumulate raw global coordinates — post-process after all lines received
            onRead: (line) => {
                var p = line.split("|")
                if (p.length < 7) return
                var wsId = parseInt(p[0])
                if (isNaN(wsId)) return
                var win = {
                    title: p[1], cls: p[2],
                    x: parseFloat(p[3]), y: parseFloat(p[4]),
                    w: parseFloat(p[5]), h: parseFloat(p[6])
                }
                if (!root._rawWindows[wsId]) root._rawWindows[wsId] = []
                root._rawWindows[wsId].push(win)
            }
        }
        onRunningChanged: {
            if (!running) {
                // Convert global coords → per-workspace monitor-relative coords
                var result = {}
                var monMap = root.monitorByWs
                for (var wsIdStr in root._rawWindows) {
                    var wsId = parseInt(wsIdStr)
                    var mon  = monMap[wsId] || { x: 0, y: 0, w: 1920, h: 1080 }
                    var wins = root._rawWindows[wsIdStr]
                    var out  = []
                    for (var i = 0; i < wins.length; i++) {
                        var win  = wins[i]
                        var relX = win.x - mon.x
                        var relY = win.y - mon.y
                        // Keep only windows whose center falls within this monitor's bounds
                        if ((relX + win.w / 2) >= 0 && (relX + win.w / 2) <= mon.w &&
                            (relY + win.h / 2) >= 0 && (relY + win.h / 2) <= mon.h) {
                            out.push({ title: win.title, cls: win.cls,
                                       x: relX, y: relY, w: win.w, h: win.h })
                        }
                    }
                    result[wsId] = out
                }
                root.windowsByWs = result
                root.loaded = true
            }
        }
    }
}
