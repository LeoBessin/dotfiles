import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

BarWidget {
    id: root

    property var barScreen

    onClicked: NotifService.toggleCenter(barScreen)

    content: RowLayout {
        spacing: 3

        Text {
            // Use strikethrough-bell glyph when DND is on
            text: NotifService.dnd
                  ? ""   // notifications_off
                  : NotifService.unreadCount > 0 ? "" : ""
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize
            color: root.hovered
                   ? Theme.accent
                   : NotifService.dnd
                     ? Theme.fgDim
                     : NotifService.unreadCount > 0 ? Theme.fg : Theme.fgDim
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Rectangle {
            visible: NotifService.unreadCount > 0 && !NotifService.dnd
            implicitWidth:  badgeLabel.implicitWidth + 6
            implicitHeight: 13
            radius: 6
            color:  Theme.accent

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text:  NotifService.unreadCount > 9 ? "9+" : NotifService.unreadCount
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
                font.weight:    Font.Bold
                color: Theme.bgSolid
            }
        }
    }
}
