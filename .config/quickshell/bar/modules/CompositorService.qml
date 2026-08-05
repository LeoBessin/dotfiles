// CompositorService.qml — the shell's only compositor-aware type.
//
// Workspaces and windows come from cross-compositor Wayland protocols, so
// switching a workspace or focusing a window needs no compositor-specific code:
//
//   workspaces → Quickshell.WindowManager   (ext-workspace-v1)
//   windows    → ToplevelManager            (wlr-foreign-toplevel-management-v1)
//
// Both Hyprland (≥ 0.50) and niri (≥ 25.08) implement both protocols.
//
// Exactly two things have no protocol and are delegated to a read-only backend
// under compositor/: the focused output, and per-window geometry for the
// workspace-overview mini-map. Everything else here is protocol-driven.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.WindowManager
import "."

Item {
    id: root
    visible: false
    width: 0; height: 0

    // ── Identity ──────────────────────────────────────────────────────────
    // Env is authoritative and synchronous: both compositors export a socket
    // path, so no probing subprocess is needed.
    readonly property string compositor: {
        if (Quickshell.env("NIRI_SOCKET")) return "niri"
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) return "hyprland"
        var desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase()
        if (desktop.indexOf("niri") >= 0) return "niri"
        if (desktop.indexOf("hyprland") >= 0) return "hyprland"
        return "unknown"
    }

    readonly property bool isHyprland: compositor === "hyprland"
    readonly property bool isNiri:     compositor === "niri"

    // ScreencopyView can only capture a toplevel via hyprland-toplevel-export-v1,
    // which niri does not implement. Consumers that show live window previews must
    // gate on this and fall back to a static card.
    readonly property bool canCaptureToplevels: isHyprland

    // ── Compositor-specific commands ──────────────────────────────────────
    readonly property var lockCommand: {
        if (Config.lockCommand && Config.lockCommand.length > 0) return Config.lockCommand
        if (isHyprland) return ["hyprlock"]
        if (isNiri)     return ["swaylock", "-f"]
        return ["loginctl", "lock-session"]
    }

    // ── Live protocol state ───────────────────────────────────────────────
    // These bindings exist to be eager: each protocol's wayland global is only
    // bound when its list is first read, and the first read comes back empty
    // because the initial state arrives a roundtrip later. Reading both here, at
    // singleton construction, gets the globals bound before anything renders.
    // Every function below goes through these so bindings stay reactive.
    readonly property var workspaces: WindowManager.windowsets
    readonly property var toplevels: ToplevelManager.toplevels.values

    // ── Windows — wlr-foreign-toplevel-management ─────────────────────────
    readonly property var activeToplevel: ToplevelManager.activeToplevel

    // Every open window, or only those visible on `screen` when one is given.
    function toplevelsForScreen(screen) {
        var out = []
        var all = root.toplevels
        for (var i = 0; i < all.length; i++) {
            if (!screen || _onScreen(all[i].screens, screen)) out.push(all[i])
        }
        return out
    }

    // Focus a window. This is deliberately two requests, not one: Hyprland
    // silently ignores Toplevel.activate() when the window sits on a workspace
    // that is not currently visible, which is the common case for a window
    // switcher. Activating the workspace first fixes it, and the two can be sent
    // in the same tick.
    //
    // No protocol links a toplevel to a workspace, so the pairing comes from the
    // backend snapshot and is matched on title — the same way the workspace
    // overview matches its previews.
    function focusToplevel(toplevel) {
        if (!toplevel) return
        var title = toplevel.title || ""
        var appId = toplevel.appId || ""
        queryOverview(function (overview) {
            var windowset = root._windowsetHoldingWindow(overview, title, appId)
            if (windowset && !windowset.active) windowset.activate()
            toplevel.activate()
        })
    }

    // The focused window, but only if it is on `screen` — lets a per-monitor bar
    // show a title only when the focus is actually on that monitor.
    function activeToplevelOnScreen(screen) {
        var top = ToplevelManager.activeToplevel
        if (!top) return null
        if (screen && !_onScreen(top.screens, screen)) return null
        return top
    }

    // ── Workspaces — ext-workspace-v1 ─────────────────────────────────────
    // Reads the bindable workspace list so QML bindings that call this
    // re-evaluate when workspaces appear, vanish or move between monitors.
    function workspacesForScreen(screen) {
        var out = []
        if (!screen) return out
        var all = root.workspaces
        for (var i = 0; i < all.length; i++) {
            var ws = all[i]
            if (!ws.shouldDisplay || _isSpecial(ws)) continue
            if (ws.projection && _onScreen(ws.projection.screens, screen)) out.push(ws)
        }
        out.sort(_compareWorkspaces)
        return out
    }

    function activeWorkspaceForScreen(screen) {
        var list = workspacesForScreen(screen)
        for (var i = 0; i < list.length; i++)
            if (list[i].active) return list[i]
        return null
    }

    // ── Focused output ────────────────────────────────────────────────────
    // Async because it needs compositor IPC. `cb` always receives a ShellScreen
    // (or null when no screen is connected at all).
    function withFocusedScreen(cb) {
        var backend = backendLoader.item
        if (!backend) {
            cb(_guessFocusedScreen())
            return
        }
        backend.focusedOutput(function (outputName) {
            cb(_screenByName(outputName) || _guessFocusedScreen())
        })
    }

    // ── Native workspace overview ─────────────────────────────────────────
    // True when the compositor has its own overview worth using instead of the
    // shell's WorkspaceSwitcher (niri does; Hyprland does not).
    readonly property bool hasNativeOverview: backendLoader.item ? backendLoader.item.hasOverview : false

    function toggleNativeOverview() {
        if (!hasNativeOverview) return false
        backendLoader.item.toggleOverview()
        return true
    }

    // ── Workspace overview ────────────────────────────────────────────────
    // Every workspace on every monitor, keyed by an opaque "<output>:<name>" key:
    //
    //   keys           ordered keys, grouped by monitor
    //   nameByWs       key → workspace label ("1", "web", …)
    //   monitorByWs    key → { w, h } logical size of that workspace's monitor
    //   windowsetByKey key → Windowset, whose activate() switches to it
    //   activeKey      key of the active workspace on `focusedScreen`
    //   labelByWs      key → "" (filled in by queryOverview)
    //   windowsByWs    key → [] (filled in by queryOverview)
    //
    // Protocol-only, so it is synchronous: callers can lay out immediately and
    // let queryOverview fill in the geometry a moment later.
    function workspaceIndex(focusedScreen) {
        var result = {
            keys: [], nameByWs: {}, labelByWs: {}, windowsByWs: {},
            monitorByWs: {}, windowsetByKey: {}, activeKey: ""
        }
        var focusedName = focusedScreen ? focusedScreen.name : ""
        var screens = Quickshell.screens
        for (var s = 0; s < screens.length; s++) {
            var screen = screens[s]
            var workspaces = workspacesForScreen(screen)
            for (var j = 0; j < workspaces.length; j++) {
                var ws = workspaces[j]
                var key = _wsKey(screen.name, ws.name)
                result.keys.push(key)
                result.nameByWs[key]       = String(ws.name)
                result.labelByWs[key]      = ""
                result.windowsByWs[key]    = []
                result.monitorByWs[key]    = { w: screen.width, h: screen.height }
                result.windowsetByKey[key] = ws

                // Prefer the active workspace on the focused monitor; otherwise
                // take any active workspace so the key is never empty.
                if (ws.active && (screen.name === focusedName || result.activeKey === ""))
                    result.activeKey = key
            }
        }
        if (result.activeKey === "" && result.keys.length > 0)
            result.activeKey = result.keys[0]
        return result
    }

    // workspaceIndex plus the two things only compositor IPC can answer: each
    // workspace's last-focused window title, and its windows' geometry in
    // monitor-local logical coordinates.
    function queryOverview(cb) {
        var backend = backendLoader.item
        if (!backend) {
            cb(_buildOverview({ focusedOutput: "", workspaces: [] }))
            return
        }
        backend.queryOverview(function (raw) { cb(root._buildOverview(raw)) })
    }

    // ── Internals ─────────────────────────────────────────────────────────
    function _onScreen(screens, screen) {
        if (!screens || !screen) return false
        for (var i = 0; i < screens.length; i++)
            if (screens[i] && screens[i].name === screen.name) return true
        return false
    }

    // Hyprland names its scratchpads "special:<name>" and gives them no
    // coordinates; they are not places you tab through.
    function _isSpecial(ws) {
        if (String(ws.name || "").indexOf("special:") === 0) return true
        return !ws.coordinates || ws.coordinates.length === 0
    }

    // Hyprland sends 1-D coordinates ([id]), niri 2-D ([0, index]).
    function _compareWorkspaces(a, b) {
        var ca = a.coordinates || []
        var cb = b.coordinates || []
        var n = Math.max(ca.length, cb.length)
        for (var i = 0; i < n; i++) {
            var va = i < ca.length ? ca[i] : -1
            var vb = i < cb.length ? cb[i] : -1
            if (va !== vb) return va - vb
        }
        return String(a.name).localeCompare(String(b.name), undefined, { numeric: true })
    }

    // Workspace names are unique per output but not globally (two niri outputs
    // both have a workspace "1"), so keys carry the output.
    function _wsKey(output, name) {
        return String(output) + ":" + String(name)
    }

    // Title alone can collide (two terminals, two "Untitled" documents), so an
    // app-id match is preferred and a title-only match is the fallback.
    function _windowsetHoldingWindow(overview, title, appId) {
        if (!title) return null
        var titleOnlyMatch = null
        for (var i = 0; i < overview.keys.length; i++) {
            var key = overview.keys[i]
            var windows = overview.windowsByWs[key]
            for (var j = 0; j < windows.length; j++) {
                if (windows[j].title !== title) continue
                if (appId && windows[j].cls === appId) return overview.windowsetByKey[key]
                if (!titleOnlyMatch) titleOnlyMatch = overview.windowsetByKey[key]
            }
        }
        return titleOnlyMatch
    }

    function _screenByName(name) {
        if (!name) return null
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++)
            if (screens[i].name === name) return screens[i]
        return null
    }

    // Used when the backend is missing or its answer names an unknown output.
    function _guessFocusedScreen() {
        var top = ToplevelManager.activeToplevel
        if (top && top.screens.length > 0) return top.screens[0]
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    function _buildOverview(raw) {
        var focusedOutput = (raw && raw.focusedOutput) ? raw.focusedOutput : ""
        var result = workspaceIndex(_screenByName(focusedOutput))

        // Backend entries are matched onto the protocol's workspaces by
        // (output, name); anything the protocol does not list — a scratchpad, a
        // workspace on a disconnected output — is dropped.
        var rawList = (raw && raw.workspaces) ? raw.workspaces : []
        for (var i = 0; i < rawList.length; i++) {
            var entry = rawList[i]
            var key = _wsKey(entry.output, entry.name)
            if (!result.windowsetByKey[key]) continue
            result.labelByWs[key]   = entry.label || ""
            result.windowsByWs[key] = entry.windows || []
            if (entry.monitor) result.monitorByWs[key] = entry.monitor
        }
        return result
    }

    // Loaded lazily by path so Quickshell.Hyprland / niri IPC are never touched
    // on the wrong compositor.
    Loader {
        id: backendLoader
        source: root.isHyprland ? "compositor/HyprlandBackend.qml"
              : root.isNiri     ? "compositor/NiriBackend.qml"
              : ""
    }

    Component.onCompleted: {
        if (compositor === "unknown")
            console.warn("CompositorService: unrecognised compositor — workspace overview "
                         + "and focused-output detection will be degraded")
    }
}
