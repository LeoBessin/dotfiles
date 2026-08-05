// center/Workspaces.qml — workspace pills for the current monitor
//
// Backed by ext-workspace-v1 through CompositorService, so this is compositor
// agnostic: the pills and the click-to-switch both work on any compositor that
// implements the protocol.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.WindowManager
import ".."

RowLayout {
    id: root

    // barScreen is the ShellScreen passed from Bar.qml
    property var barScreen: null

    spacing: 3

    Repeater {
        // Already filtered to this monitor and ordered by the compositor's own
        // workspace coordinates.
        model: CompositorService.workspacesForScreen(root.barScreen)

        delegate: Rectangle {
            id: pill

            required property Windowset modelData
            readonly property Windowset ws: modelData
            readonly property bool isActive: ws.active
            readonly property bool isHovered: pillHover.containsMouse

            // Named workspaces exist on niri, so the pill grows to fit its label
            // instead of assuming a single digit.
            implicitWidth:  Math.max(isActive ? 28 : 20, wsLabel.implicitWidth + 10)
            implicitHeight: 20
            radius:         Theme.pillRadius

            color: isActive  ? Theme.accent
                 : isHovered ? Theme.bgHover
                 : Qt.rgba(1, 1, 1, 0.08)

            Behavior on implicitWidth { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

            // Workspace label — a number on Hyprland, a number or name on niri
            Text {
                id: wsLabel
                anchors.centerIn: parent
                text:  pill.ws.name
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
                onClicked:     pill.ws.activate()
            }
        }
    }
}
