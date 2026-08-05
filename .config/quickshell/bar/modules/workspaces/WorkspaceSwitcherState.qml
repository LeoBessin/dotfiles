pragma Singleton
import QtQuick
import ".."

Item {
    id: root
    visible: false
    width: 0; height: 0

    property bool active:        false
    property var  targetScreen:  null
    property int  selectedIndex: 0

    // workspaceIds holds opaque keys from CompositorService ("<output>:<name>").
    // Never parse or display them — index the maps below, and use nameByWs for
    // anything the user sees.
    property var    workspaceIds: []
    property string activeWsId:   ""

    property var nameByWs:            ({})   // key → workspace label
    property var monitorByWs:         ({})   // key → {w, h} logical monitor size
    property var windowsByWs:         ({})   // key → [{title, cls, x, y, w, h}]
    property var lastWindowTitleByWs: ({})   // key → last-focused window title
    property var _windowsetByWs:      ({})   // key → Windowset (activates the workspace)

    // False until window geometry arrives; the workspace strip itself is laid out
    // immediately from the protocol snapshot.
    property bool loaded: false

    function open(screen) {
        if (active) return

        // Where the compositor has its own overview, use that instead — on niri it
        // shows real live window previews, which this switcher cannot do there
        // (no hyprland-toplevel-export-v1, so thumbnails degrade to icon cards).
        // Toggling means a second press dismisses it, matching niri's own Mod+O.
        if (CompositorService.toggleNativeOverview()) return

        targetScreen = screen

        // The protocol knows every workspace synchronously, so the overlay can be
        // drawn on this frame. Only the geometry needs compositor IPC.
        _apply(CompositorService.workspaceIndex(screen), false)
        selectedIndex = Math.max(0, workspaceIds.indexOf(activeWsId))
        active = true

        CompositorService.queryOverview(function (overview) {
            // The overlay may have been dismissed while the query was in flight.
            if (!root.active) return
            var previousKey = root.workspaceIds[root.selectedIndex]
            root._apply(overview, true)
            // Keep the highlight on whatever the user had selected.
            var restored = root.workspaceIds.indexOf(previousKey)
            root.selectedIndex = restored >= 0
                ? restored
                : Math.max(0, root.workspaceIds.indexOf(root.activeWsId))
        })
    }

    function close() {
        active       = false
        targetScreen = null
        loaded       = false
    }

    function confirm() {
        if (!active || workspaceIds.length === 0) return
        var key = workspaceIds[selectedIndex]
        var windowset = _windowsetByWs[key]
        // Windowset.activate() is the cross-compositor workspace switch —
        // ext-workspace-v1, no dispatcher strings.
        if (windowset) windowset.activate()
        close()
    }

    function _apply(overview, isLoaded) {
        workspaceIds        = overview.keys
        activeWsId          = overview.activeKey
        nameByWs            = overview.nameByWs
        monitorByWs         = overview.monitorByWs
        windowsByWs         = overview.windowsByWs
        lastWindowTitleByWs = overview.labelByWs
        _windowsetByWs      = overview.windowsetByKey
        loaded              = isLoaded
    }
}
