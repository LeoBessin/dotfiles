// center/Workspaces.qml — workspace pills for the current monitor
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import ".."

RowLayout {
    id: root

    // barScreen is the ShellScreen passed from Bar.qml
    property var barScreen: null

    spacing: 3

    // Derive which HyprlandMonitor corresponds to this bar's screen
    property HyprlandMonitor monitor: {
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
            var m = Hyprland.monitors.values[i]
            if (barScreen && m.name === barScreen.name)
                return m
        }
        return Hyprland.focusedMonitor
    }

    Repeater {
        // Sort workspaces by id, filter to this monitor
        model: {
            var all = Hyprland.workspaces.values
            var mine = []
            for (var i = 0; i < all.length; i++) {
                if (all[i].monitor && all[i].monitor.name && root.monitor && root.monitor.name && all[i].monitor.name === root.monitor.name)
                    mine.push(all[i])
            }
            mine.sort(function(a, b) { return a.id - b.id })
            return mine
        }

        delegate: Rectangle {
            id: pill

            property HyprlandWorkspace ws: modelData
            property bool isActive: root.monitor && root.monitor.activeWorkspace
                                    && root.monitor.activeWorkspace.id === ws.id
            property bool isHovered: pillHover.containsMouse

            implicitWidth:  isActive ? 28 : 20
            implicitHeight: 20
            radius:         Theme.pillRadius

            color: isActive  ? Theme.accent
                 : isHovered ? Theme.bgHover
                 : Qt.rgba(1, 1, 1, 0.08)


            Behavior on implicitWidth { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

            // Workspace number label
            Text {
                anchors.centerIn: parent
                text:  ws.id
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                font.weight:    pill.isActive ? Font.Bold : Font.Normal
                color: pill.isActive ? Theme.bgSolid : Theme.fg

            }

            MouseArea {
                id: pillHover
                anchors.fill:  parent
                hoverEnabled:  true
                cursorShape:   Qt.PointingHandCursor
                onClicked:     Hyprland.dispatch("hl.dsp.focus({ workspace = " + ws.id + " })")
            }
        }
    }
}
