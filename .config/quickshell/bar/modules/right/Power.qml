// right/Power.qml — power menu popup (logout / reboot / shutdown)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: root
    implicitWidth:  triggerBtn.implicitWidth
    implicitHeight: Theme.barHeight

    property bool menuOpen: false

    // ── Trigger button ────────────────────────────────────────────────────
    Rectangle {
        id: triggerBtn
        implicitWidth:  24 + Theme.widgetPad * 2
        implicitHeight: Theme.barHeight
        radius:         Theme.pillRadius
        color:          triggerHover.containsMouse ? Theme.bgHover : "transparent"

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors.centerIn: parent
            text:  "\ue8ac"    // Material Symbols: power_settings_new
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize - 2
            color: triggerHover.containsMouse ? Theme.red : Theme.fgDim
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        MouseArea {
            id: triggerHover
            anchors.fill:  parent
            hoverEnabled:  true
            cursorShape:   Qt.PointingHandCursor
            onClicked:     root.menuOpen = !root.menuOpen
        }
    }

    // ── Power popup ───────────────────────────────────────────────────────
    PopupWindow {
        id: powerPopup
        visible: root.menuOpen
        grabFocus: true

        anchor.item:    triggerBtn
        anchor.gravity: Edges.Bottom | Edges.Right

        implicitWidth:  160
        implicitHeight: popupCol.implicitHeight + 16
        color:  "transparent"

        // Close when focus is lost (click outside)
        onClosed: root.menuOpen = false

        Keys.onEscapePressed: root.menuOpen = false

        Rectangle {
            anchors.fill:  parent
            color:         Theme.bgPopup
            radius:        Theme.radius
            border.color:  Qt.rgba(0.70, 0.62, 0.86, 0.20)
            border.width:  1

            Column {
                id: popupCol
                anchors {
                    top:   parent.top
                    left:  parent.left
                    right: parent.right
                    topMargin:  8
                    leftMargin: 8
                    rightMargin: 8
                }
                spacing: 4

                PowerButton {
                    icon:    "\ue9ba"   // logout
                    label:   "Log out"
                    iconColor: Theme.fg
                    command: ["bash", "-c", "loginctl terminate-user $USER"]
                    onActivated: root.menuOpen = false
                }

                PowerButton {
                    icon:    "\ue8d0"   // restart_alt
                    label:   "Reboot"
                    iconColor: Theme.yellow
                    command: ["systemctl", "reboot"]
                    onActivated: root.menuOpen = false
                }

                PowerButton {
                    icon:    "\ue8ac"   // power_settings_new
                    label:   "Shutdown"
                    iconColor: Theme.red
                    command: ["systemctl", "poweroff"]
                    onActivated: root.menuOpen = false
                }
            }
        }
    }
}
