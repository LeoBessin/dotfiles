import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Wayland._Screencopy
import ".."

PanelWindow {
    id: root

    property var modelData
    screen: modelData

    anchors.left:   true
    anchors.right:  true
    anchors.top:    true
    anchors.bottom: true

    property bool isActive: WorkspaceSwitcherState.active && WorkspaceSwitcherState.targetScreen === modelData

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "quickshell-workspaces"
    WlrLayershell.keyboardFocus: isActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    color: "transparent"
    surfaceFormat.opaque: false
    Component.onCompleted: exclusionMode = ExclusionMode.Ignore
    visible: false

    onIsActiveChanged: {
        if (isActive) {
            root.visible    = true
            root.wallpaperPath = ""
            wallpaperReader.running = false
            wallpaperReader.running = true
            _allToplevelMaps = _buildAllToplevelMaps()
            hideTimer.stop()
            focusTimer.restart()
        } else {
            hideTimer.restart()
        }
    }

    Timer { id: hideTimer;  interval: Theme.animFast + 20; onTriggered: root.visible = false }
    Timer { id: focusTimer; interval: 60;                  onTriggered: focusItem.forceActiveFocus() }

    // ── Wallpaper ──────────────────────────────────────────────────────────
    property string wallpaperPath: ""

    Process {
        id: wallpaperReader
        command: ["bash", "-c", "cat \"$HOME/.local/share/wallpapers/.current\" 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: (line) => { if (line.trim() !== "") root.wallpaperPath = line.trim() }
        }
    }

    // ── Screen dimensions (switcher screen — used for UI sizing only) ──────
    readonly property real _sw: modelData ? modelData.width  : 1920
    readonly property real _sh: modelData ? modelData.height : 1080

    // Large preview height fixed to 70% of screen; width adapts to selected workspace's aspect
    readonly property real largeH: Math.round(_sh * 0.80)
    readonly property var  _selMon: WorkspaceSwitcherState.monitorByWs[selectedWsId]
                                    ?? { w: _sw, h: _sh }
    readonly property real largeW: Math.round(largeH * _selMon.w / _selMon.h)

    // Thumbnail fixed height; width from this screen's aspect (uniform strip)
    readonly property real thumbPrevH: 72
    readonly property real thumbPrevW: Math.round(thumbPrevH * _sw / _sh)
    readonly property real thumbCardH: thumbPrevH + 26
    readonly property real thumbCardW: thumbPrevW

    readonly property int selectedWsId: {
        var ids = WorkspaceSwitcherState.workspaceIds
        if (!ids || ids.length <= WorkspaceSwitcherState.selectedIndex) return -1
        return ids[WorkspaceSwitcherState.selectedIndex]
    }

    // ── Toplevel maps for ALL workspaces: {wsId: {title: HyprlandToplevel}} ─
    property var _allToplevelMaps: ({})

    Connections {
        target: WorkspaceSwitcherState
        function onLoadedChanged() {
            if (WorkspaceSwitcherState.loaded)
                root._allToplevelMaps = root._buildAllToplevelMaps()
        }
    }

    function _buildAllToplevelMaps() {
        var result = {}
        var wss = Hyprland.workspaces.values
        for (var i = 0; i < wss.length; i++) {
            var wsId = wss[i].id
            var tops = wss[i].toplevels.values
            var map  = {}
            for (var j = 0; j < tops.length; j++) {
                var t = tops[j]
                if (t.title) map[t.title] = t
            }
            result[wsId] = map
        }
        return result
    }

    // ── Backdrop ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color:   Qt.rgba(0, 0, 0, 0.30)
        opacity: root.isActive ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        MouseArea { anchors.fill: parent; onClicked: WorkspaceSwitcherState.close() }
    }

    // ── Focus receiver + keyboard handler ──────────────────────────────────
    Item {
        id: focusItem
        anchors.fill: parent
        focus: true

        Keys.onTabPressed:     _move(1)
        Keys.onBacktabPressed: _move(-1)
        Keys.onRightPressed:   _move(1)
        Keys.onLeftPressed:    _move(-1)
        Keys.onReturnPressed:  WorkspaceSwitcherState.confirm()
        Keys.onEscapePressed:  WorkspaceSwitcherState.close()

        function _move(delta) {
            var n = WorkspaceSwitcherState.workspaceIds.length
            if (n === 0) return
            WorkspaceSwitcherState.selectedIndex =
                ((WorkspaceSwitcherState.selectedIndex + delta) % n + n) % n
        }

        // ── Content column (centered) ──────────────────────────────────────
        Column {
            anchors.centerIn: parent
            spacing: 0

            opacity: root.isActive ? 1.0 : 0.0
            scale:   root.isActive ? 1.0 : 0.97
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Behavior on scale   { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

            // ── Focused window title (above preview) ──────────────────────
            Item {
                width:  root.largeW
                height: 28
                Text {
                    anchors.centerIn: parent
                    text: WorkspaceSwitcherState.lastWindowTitleByWs[root.selectedWsId] ?? ""
                    font.family:    Theme.monoFamily
                    font.pixelSize: Theme.fontSize
                    color:          Theme.launcherFg
                    elide:          Text.ElideRight
                    width:          parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // ── Large workspace preview ────────────────────────────────────
            Rectangle {
                id: largePreview
                width:  root.largeW
                height: root.largeH
                radius: Theme.launcherRadius
                color:  Qt.rgba(0.07, 0.06, 0.12, 1.0)
                layer.enabled: true

                Image {
                    anchors.fill: parent
                    source:       root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""
                    fillMode:     Image.PreserveAspectCrop
                    asynchronous: true
                    smooth:       true
                    visible:      root.wallpaperPath !== ""
                }

                Repeater {
                    model: WorkspaceSwitcherState.windowsByWs[root.selectedWsId] ?? []

                    delegate: Item {
                        id: winItem
                        required property var modelData

                        readonly property var  _mon:       WorkspaceSwitcherState.monitorByWs[root.selectedWsId]
                                                           ?? { w: root._sw, h: root._sh }
                        readonly property real _titleH:    26
                        readonly property real _scaledX:   Math.round(modelData.x * largePreview.width  / _mon.w)
                        readonly property real _scaledY:   Math.round(modelData.y * largePreview.height / _mon.h)
                        readonly property real _scaledW:   Math.max(10, Math.round(modelData.w * largePreview.width  / _mon.w))
                        readonly property real _scaledH:   Math.max(10, Math.round(modelData.h * largePreview.height / _mon.h))

                        // Item extends upward to include the title bar above the window rect
                        x:      _scaledX
                        y:      _scaledY - _titleH
                        width:  _scaledW
                        height: _scaledH + _titleH

                        property var  _toplevel:   (root._allToplevelMaps[root.selectedWsId] ?? {})[modelData.title] ?? null
                        property bool _hasContent: _scv.hasContent

                        // Title bar above the window content
                        Rectangle {
                            id: titleBar
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: winItem._titleH
                            radius: 4
                            color:  Qt.rgba(0.12, 0.10, 0.20, 0.92)

                            RowLayout {
                                anchors { fill: parent; leftMargin: 7; rightMargin: 7 }
                                spacing: 6

                                Image {
                                    width: 14; height: 14
                                    Layout.alignment: Qt.AlignVCenter
                                    source:     (winItem.modelData.cls ?? "") !== ""
                                                ? "image://icon/" + winItem.modelData.cls : ""
                                    sourceSize: Qt.size(14, 14)
                                    fillMode:   Image.PreserveAspectFit
                                    smooth:     true
                                    visible:    (winItem.modelData.cls ?? "") !== "" && status === Image.Ready
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text:           winItem.modelData.title ?? ""
                                    font.family:    Theme.monoFamily
                                    font.pixelSize: 10
                                    color:          Theme.launcherFg
                                    elide:          Text.ElideRight
                                }

                                Rectangle {
                                    visible:          (winItem.modelData.cls ?? "") !== ""
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth:    clsText.implicitWidth + 8
                                    height:           16
                                    radius:           3
                                    color:            Qt.rgba(0.92, 0.44, 0.57, 0.12)
                                    Text {
                                        id: clsText
                                        anchors.centerIn: parent
                                        text:           winItem.modelData.cls ?? ""
                                        font.family:    Theme.monoFamily
                                        font.pixelSize: 9
                                        color:          Theme.launcherAccent
                                    }
                                }
                            }
                        }

                        // Window content area (below title bar)
                        ScreencopyView {
                            id: _scv
                            anchors { top: titleBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                            captureSource: winItem._toplevel ? winItem._toplevel.wayland : null
                            live: true
                        }

                        Rectangle {
                            anchors { top: titleBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                            visible: !winItem._hasContent
                            radius:  6
                            color:   Qt.rgba(0.20, 0.16, 0.32, 0.70)
                        }
                    }
                }

                // Accent border on top
                Rectangle {
                    anchors.fill: parent
                    color:        "transparent"
                    border.color: Theme.accent
                    border.width: 2
                    radius:       Theme.launcherRadius
                }
            }

            // ── Workspace label (below preview) ───────────────────────────
            Item {
                width:  root.largeW
                height: 28
                Text {
                    anchors.centerIn: parent
                    text: {
                        var ids = WorkspaceSwitcherState.workspaceIds
                        var sel = WorkspaceSwitcherState.selectedIndex
                        return (ids && sel < ids.length) ? "Workspace " + ids[sel] : ""
                    }
                    font.family:    Theme.monoFamily
                    font.pixelSize: Theme.fontSize
                    color:          Theme.launcherFgDim
                }
            }

            Item { width: 1; height: 4 }

            // ── Thumbnail strip ────────────────────────────────────────────
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Repeater {
                    model: WorkspaceSwitcherState.workspaceIds

                    delegate: Rectangle {
                        id: thumbCard
                        required property int index
                        required property var modelData   // workspace ID

                        readonly property bool isSelected: WorkspaceSwitcherState.selectedIndex === index
                        readonly property bool isActiveWs: modelData === WorkspaceSwitcherState.activeWsId

                        // This workspace's monitor dimensions for correct scaling
                        readonly property var _mon: WorkspaceSwitcherState.monitorByWs[modelData]
                                                    ?? { w: root._sw, h: root._sh }

                        width:  root.thumbCardW
                        height: root.thumbCardH
                        radius: Theme.pillRadius
                        color:  isActiveWs
                            ? Qt.rgba(0.19, 0.16, 0.32, 0.95)
                            : Qt.rgba(0.11, 0.09, 0.18, 0.92)
                        border.color: isSelected  ? Theme.accent
                                    : isActiveWs  ? Qt.rgba(0.70, 0.62, 0.86, 0.45)
                                    : Theme.launcherBorder
                        border.width: isSelected ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                        // ── Thumbnail preview area ─────────────────────────
                        Item {
                            id: thumbPrevArea
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: root.thumbPrevH
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0.07, 0.06, 0.12, 1.0)
                            }

                            Image {
                                anchors.fill: parent
                                source:       root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""
                                fillMode:     Image.PreserveAspectCrop
                                asynchronous: true
                                smooth:       true
                                visible:      root.wallpaperPath !== ""
                            }

                            // Window thumbnails
                            Repeater {
                                model: WorkspaceSwitcherState.windowsByWs[thumbCard.modelData] ?? []

                                delegate: Item {
                                    id: thumbWin
                                    required property var modelData

                                    x:      Math.round(modelData.x * thumbPrevArea.width  / thumbCard._mon.w)
                                    y:      Math.round(modelData.y * thumbPrevArea.height / thumbCard._mon.h)
                                    width:  Math.max(3, Math.round(modelData.w * thumbPrevArea.width  / thumbCard._mon.w))
                                    height: Math.max(3, Math.round(modelData.h * thumbPrevArea.height / thumbCard._mon.h))

                                    property var  _toplevel:   (root._allToplevelMaps[thumbCard.modelData] ?? {})[modelData.title] ?? null
                                    property bool _hasContent: _tscv.hasContent

                                    ScreencopyView {
                                        id: _tscv
                                        anchors.fill: parent
                                        captureSource: thumbWin._toplevel ? thumbWin._toplevel.wayland : null
                                        live: true
                                        constraintSize: Qt.size(thumbWin.width * 2, thumbWin.height * 2)
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        visible:      !thumbWin._hasContent
                                        radius:       2
                                        color:        Qt.rgba(0.28, 0.24, 0.42, 0.80)
                                    }
                                }
                            }
                        }

                        // ── Workspace number ───────────────────────────────
                        Text {
                            anchors {
                                bottom:           parent.bottom
                                horizontalCenter: parent.horizontalCenter
                                bottomMargin:     4
                            }
                            text:           thumbCard.modelData.toString()
                            font.family:    Theme.monoFamily
                            font.pixelSize: Theme.fontSize - 1
                            font.weight:    thumbCard.isSelected ? Font.Bold : Font.Normal
                            color: thumbCard.isSelected ? Theme.launcherFg : Theme.launcherFgDim
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onEntered:    WorkspaceSwitcherState.selectedIndex = thumbCard.index
                            onClicked: {
                                WorkspaceSwitcherState.selectedIndex = thumbCard.index
                                WorkspaceSwitcherState.confirm()
                            }
                        }
                    }
                }
            }
        }
    }
}
