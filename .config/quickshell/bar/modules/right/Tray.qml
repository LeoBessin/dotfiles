// right/Tray.qml — system tray with DBusMenu popups
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import ".."

RowLayout {
    id: root
    spacing: 0

    Repeater {
        model: SystemTray.items

        delegate: Rectangle {
            id: trayItem

            property SystemTrayItem item: modelData

            implicitWidth:  Theme.iconSize + 8
            implicitHeight: Theme.barHeight
            radius:         Theme.pillRadius
            color:          itemHover.containsMouse ? Theme.bgHover : "transparent"

            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            // App icon
            IconImage {
                anchors.centerIn: parent
                source:  trayItem.item.icon
                implicitSize: Theme.iconSize + 2
            }

            // DBusMenu anchor
            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.item.menu
                anchor.item: trayItem
            }

            MouseArea {
                id: itemHover
                anchors.fill:    parent
                hoverEnabled:    true
                cursorShape:     Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        menuAnchor.open()
                    } else {
                        trayItem.item.activate()
                    }
                }
            }
        }
    }
}
