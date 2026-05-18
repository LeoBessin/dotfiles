// center/ActiveWindow.qml — focused window title on this monitor
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import ".."

Item {
    id: root

    property var barScreen: null

    property HyprlandMonitor monitor: {
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
            var m = Hyprland.monitors.values[i]
            if (barScreen && m.name === barScreen.name)
                return m
        }
        return Hyprland.focusedMonitor
    }

    property string windowTitle: {
        var ws = monitor ? monitor.activeWorkspace : null
        if (!ws) return ""
        var toplevels = ws.toplevels.values
        // prefer the activated one
        for (var i = 0; i < toplevels.length; i++) {
            if (toplevels[i].activated)
                return toplevels[i].title || ""
        }
        // fall back to last remembered title
        return root._lastTitle
    }

    property string _lastTitle: ""

    onWindowTitleChanged: {
        if (windowTitle.length > 0)
            _lastTitle = windowTitle
    }

    implicitWidth:  windowTitle.length > 0 ? titleRow.implicitWidth + Theme.widgetPad * 2 : 0
    implicitHeight: Theme.barHeight
    visible:        windowTitle.length > 0

    RowLayout {
        id: titleRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text:  "\ue88e"   // Material Symbols: window
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize
            color: Theme.fgDim
        }

        Text {
            text: {
                var t = root.windowTitle
                return t.length > 48 ? t.slice(0, 46) + "…" : t
            }
            font.family:    Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fg
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
