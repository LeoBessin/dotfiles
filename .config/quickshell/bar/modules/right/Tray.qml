// right/Tray.qml — system tray with custom icon-bearing popup menus
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
                source:      trayItem.item.icon
                implicitSize: Theme.iconSize + 2
            }

            // ── Custom popup menu ─────────────────────────────────────────
            PopupWindow {
                id: popup
                visible: false
                anchor.item:    trayItem
                anchor.edges:   Edges.Bottom
                anchor.gravity: Edges.Bottom

                implicitWidth:  menuCol.implicitWidth + 16
                implicitHeight: menuCol.implicitHeight + 12
                color: "transparent"

                onVisibleChanged: {
                    var rootItem = trayItem.item.hasMenu && trayItem.item.menu && trayItem.item.menu.menu
                    if (!rootItem) return
                    if (visible) rootItem.sendOpened()
                    else rootItem.sendClosed()
                }

                QsMenuOpener {
                    id: opener
                    menu: trayItem.item.menu
                }

                Rectangle {
                    anchors.fill: parent
                    color:        Theme.bgPopup
                    radius:       Theme.radius
                    border.color: Qt.rgba(0.70, 0.62, 0.86, 0.20)
                    border.width: 1

                    // Close on click outside
                    MouseArea {
                        anchors.fill: parent
                        onClicked: popup.visible = false
                    }

                    Column {
                        id: menuCol
                        anchors {
                            top:   parent.top
                            left:  parent.left
                            right: parent.right
                            topMargin:  6
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: 2

                        Repeater {
                            model: opener.children.values

                            delegate: Loader {
                                required property var modelData
                                width: menuCol.width

                                // Separator or normal item
                                sourceComponent: modelData.isSeparator ? separatorComp : menuItemComp

                                property var _entry: modelData
                            }
                        }
                    }
                }

                // ── Separator component ───────────────────────────────────
                Component {
                    id: separatorComp
                    Rectangle {
                        width:  parent ? parent.width : 0
                        height: 1
                        color:  Qt.rgba(0.70, 0.62, 0.86, 0.15)
                        anchors.margins: 4
                    }
                }

                // ── Menu item component ───────────────────────────────────
                Component {
                    id: menuItemComp
                    Rectangle {
                        id: menuRow
                        // Access parent Loader's _entry via Loader.item chain
                        property var entry: parent ? parent._entry : null

                        width:  parent ? parent.width : 200
                        implicitHeight: itemLayout.implicitHeight + 8
                        radius: Theme.pillRadius - 2
                        color:  enabled && rowHover.containsMouse
                                ? Theme.bgHover
                                : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        opacity: entry && entry.enabled ? 1.0 : 0.45

                        RowLayout {
                            id: itemLayout
                            anchors {
                                left:  parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin:  6
                                rightMargin: 6
                            }
                            spacing: 8

                            // Icon
                            Item {
                                implicitWidth:  16
                                implicitHeight: 16

                                IconImage {
                                    anchors.fill: parent
                                    // icon may be a name ("firefox") or already an image:// URL
                                    source: {
                                        if (!menuRow.entry || menuRow.entry.icon === "") return ""
                                        var ic = menuRow.entry.icon
                                        return ic.startsWith("image://") || ic.startsWith("/") || ic.startsWith("file://")
                                               ? ic
                                               : "image://icon/" + ic
                                    }
                                    implicitSize: 16
                                    visible: !!(menuRow.entry && menuRow.entry.icon !== "")
                                }
                            }

                            Text {
                                text:  menuRow.entry ? menuRow.entry.text : ""
                                font.family:    Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                color: Theme.fg
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Submenu arrow
                            Text {
                                visible: !!(menuRow.entry && menuRow.entry.children && menuRow.entry.children.count > 0)
                                text:  ""   // chevron_right
                                font.family:    Theme.iconFamily
                                font.pixelSize: 14
                                color: Theme.fgDim
                            }
                        }

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            enabled: !!(menuRow.entry && menuRow.entry.enabled)
                            onClicked: {
                                if (menuRow.entry) menuRow.entry.sendTriggered()
                                popup.visible = false
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: itemHover
                anchors.fill:    parent
                hoverEnabled:    true
                cursorShape:     Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        if (trayItem.item.hasMenu) popup.visible = !popup.visible
                    } else {
                        trayItem.item.activate()
                        popup.visible = false
                    }
                }
            }
        }
    }
}
