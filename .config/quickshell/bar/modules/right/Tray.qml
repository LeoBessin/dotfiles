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

            IconImage {
                anchors.centerIn: parent
                source:      trayItem.item.icon
                implicitSize: Theme.iconSize + 2
            }

            // ── Custom popup menu ─────────────────────────────────────────
            PopupWindow {
                id: popup
                visible: false
                grabFocus: true
                anchor.item:    trayItem
                anchor.edges:   Edges.Bottom
                anchor.gravity: Edges.Bottom

                implicitWidth:  Math.max(180, menuCol.implicitWidth + 16)
                implicitHeight: menuCol.implicitHeight + 12
                color: "transparent"

                // Stack of parent menu handles for back navigation
                property var menuStack: []

                onVisibleChanged: {
                    if (!visible) menuStack = []
                }

                Connections {
                    target: popup._backingWindow
                    enabled: popup.visible
                    function onActiveChanged() { if (!target.active) popup.visible = false }
                }

                QsMenuOpener {
                    id: opener
                    menu: trayItem.item.menu
                }

                // Sub-opener used when drilling into a submenu
                QsMenuOpener {
                    id: subOpener
                    menu: null
                }

                Rectangle {
                    anchors.fill: parent
                    color:        Theme.bgPopup
                    radius:       Theme.radius
                    border.color: Qt.rgba(0.70, 0.62, 0.86, 0.20)
                    border.width: 1

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

                        // ── Back button (shown when inside a submenu) ─────
                        Rectangle {
                            visible: popup.menuStack.length > 0
                            width:   menuCol.width
                            implicitHeight: backRow.implicitHeight + 8
                            radius: Theme.pillRadius - 2
                            color:  backHover.containsMouse ? Theme.bgHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                id: backRow
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 6; rightMargin: 6
                                }
                                spacing: 6
                                Text {
                                    text: ""   // chevron_left
                                    font.family:    Theme.iconFamily
                                    font.pixelSize: 14
                                    color: Theme.fgDim
                                }
                                Text {
                                    text: "Back"
                                    font.family:    Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                            }
                            MouseArea {
                                id: backHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    var stack = popup.menuStack.slice()
                                    var prev = stack.pop()
                                    popup.menuStack = stack
                                    subOpener.menu = stack.length > 0 ? prev : null
                                }
                            }
                        }

                        // ── Menu items ────────────────────────────────────
                        Repeater {
                            model: subOpener.menu ? subOpener.children.values : opener.children.values

                            delegate: Rectangle {
                                required property var modelData
                                property var entry: modelData

                                width:  menuCol.width
                                implicitHeight: entry && entry.isSeparator ? 5 : itemRow.implicitHeight + 8
                                radius: Theme.pillRadius - 2
                                color:  !entry || entry.isSeparator ? "transparent"
                                        : rowHover.containsMouse ? Theme.bgHover : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                opacity: entry && entry.enabled ? 1.0 : 0.45

                                Rectangle {
                                    visible: entry && entry.isSeparator
                                    anchors.centerIn: parent
                                    width: parent.width - 8
                                    height: 1
                                    color: Qt.rgba(0.70, 0.62, 0.86, 0.15)
                                }

                                RowLayout {
                                    id: itemRow
                                    visible: entry && !entry.isSeparator
                                    anchors {
                                        left:  parent.left
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        leftMargin:  6
                                        rightMargin: 6
                                    }
                                    spacing: 8

                                    Item {
                                        implicitWidth:  16
                                        implicitHeight: 16
                                        visible: !!(entry && entry.icon !== "")

                                        IconImage {
                                            anchors.fill: parent
                                            source: {
                                                if (!entry || entry.icon === "") return ""
                                                var ic = entry.icon
                                                return ic.startsWith("image://") || ic.startsWith("/") || ic.startsWith("file://")
                                                       ? ic : "image://icon/" + ic
                                            }
                                            implicitSize: 16
                                        }
                                    }

                                    Text {
                                        text: entry ? entry.text : ""
                                        font.family:    Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        color: Theme.fg
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: !!(entry && entry.hasChildren)
                                        text:  ""
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
                                    enabled: !!(entry && entry.enabled && !entry.isSeparator)
                                    onClicked: {
                                        if (!entry) return
                                        if (entry.hasChildren) {
                                            var stack = popup.menuStack.slice()
                                            stack.push(subOpener.menu)
                                            popup.menuStack = stack
                                            subOpener.menu = entry
                                        } else {
                                            entry.triggered()
                                            popup.visible = false
                                        }
                                    }
                                }
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
