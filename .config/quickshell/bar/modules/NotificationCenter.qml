import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow {
    id: root

    property var modelData
    screen: modelData

    anchors.left:   true
    anchors.right:  true
    anchors.top:    true
    anchors.bottom: true

    property bool isActive: NotifService.centerOpen && NotifService.targetScreen === modelData

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "quickshell-notif-center"
    WlrLayershell.keyboardFocus: root.isActive
                                 ? WlrKeyboardFocus.OnDemand
                                 : WlrKeyboardFocus.None

    color: "transparent"
    surfaceFormat.opaque: false

    visible: false
    onVisibleChanged: if (!visible && root.isActive) NotifService.centerOpen = false

    onIsActiveChanged: {
        if (root.isActive) {
            root.visible = true
            hideTimer.stop()
            markReadTimer.restart()
        } else {
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: Theme.animMed + 20
        onTriggered: root.visible = false
    }

    Timer {
        id: markReadTimer
        interval: 800
        onTriggered: NotifService.markAllRead()
    }

    // ── Backdrop ──────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: NotifService.closeCenter()
    }

    // ── Slide-in panel ────────────────────────────────────────────────────
    Rectangle {
        id: panelContent
        anchors.top:         parent.top
        anchors.bottom:      parent.bottom
        anchors.right:       parent.right
        anchors.topMargin:   Theme.barHeight + 6
        anchors.rightMargin: root.isActive ? 8 : -width

        width: 380

        opacity: root.isActive ? 1.0 : 0.0

        Behavior on anchors.rightMargin {
            NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.animFast }
        }

        color:        Theme.bg
        radius:       Theme.radius
        border.color: Qt.rgba(0.70, 0.62, 0.86, 0.20)
        border.width: 1

        MouseArea { anchors.fill: parent }

        // Active tab index: 0=Notifications, 1=Caffeine, 2=Calendar
        property int activeTab: 0

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: 12
            spacing: 8

            // ── Header: title + clear all ─────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: panelContent.activeTab === 0 ? "Notifications"
                        : panelContent.activeTab === 1 ? "Caffeine"
                        : "Calendar"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.weight:    Font.SemiBold
                    color: Theme.fg
                    Layout.fillWidth: true
                }

                // Clear all (only on notifications tab)
                Rectangle {
                    visible: panelContent.activeTab === 0 && NotifService.historyModel.count > 0
                    implicitWidth:  clearLabel.implicitWidth + 12
                    implicitHeight: 22
                    radius: Theme.pillRadius
                    color:  clearMouse.containsMouse ? Theme.bgHover : Qt.rgba(1,1,1,0.06)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text:  "Clear all"
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        color: clearMouse.containsMouse ? Theme.accent : Theme.fgDim
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    NotifService.clearAll()
                    }
                }
            }

            // ── Media player ──────────────────────────────────────────────
            MediaPlayerWidget {
                id: mediaWidget
                Layout.fillWidth: true
            }

            Rectangle {
                visible: mediaWidget.visible
                Layout.fillWidth: true
                height: 1
                color:  Qt.rgba(0.70, 0.62, 0.86, 0.10)
            }

            // ── DND row ───────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text:  ""   // Material Symbols: bedtime
                    font.family:    Theme.iconFamily
                    font.pixelSize: Theme.iconSize - 1
                    color: NotifService.dnd ? Theme.accent : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Text {
                    text:  "Do not disturb"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                    Layout.fillWidth: true
                }

                // Toggle switch
                Rectangle {
                    id: dndSwitch
                    width:  44
                    height: 24
                    radius: 12
                    color:  NotifService.dnd ? Theme.accent : Qt.rgba(0.30, 0.28, 0.45, 0.70)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width:  20
                        height: 20
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        x: NotifService.dnd ? parent.width - width - 2 : 2
                        color: "white"
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    NotifService.dnd = !NotifService.dnd
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color:  Qt.rgba(0.70, 0.62, 0.86, 0.15)
            }

            // ── Tab content area ──────────────────────────────────────────
            Item {
                Layout.fillWidth:  true
                Layout.fillHeight: true

                // Tab 0: Notifications
                Item {
                    anchors.fill: parent
                    visible: panelContent.activeTab === 0

                    Text {
                        visible: NotifService.historyModel.count === 0
                        anchors.centerIn: parent
                        text:    "No notifications"
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color:  Theme.fgDim
                    }

                    ScrollView {
                        anchors.fill: parent
                        visible: NotifService.historyModel.count > 0
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.vertical.policy:   ScrollBar.AsNeeded
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        Column {
                            width:   parent.width
                            spacing: 8

                            Repeater {
                                model: NotifService.appGroupsModel

                                delegate: NotifAppGroup {
                                    required property var model

                                    width:       parent.width
                                    appName:     model.appName
                                    appIcon:     model.appIcon
                                    count:       model.count
                                    unreadCount: model.unreadCount
                                    collapsed:   model.collapsed

                                    onToggleCollapse: NotifService.toggleAppCollapsed(model.appName)
                                    onClearRequested: NotifService.clearApp(model.appName)
                                }
                            }
                        }
                    }
                }

                // Tab 1: Caffeine
                Item {
                    anchors.fill: parent
                    visible: panelContent.activeTab === 1

                    ColumnLayout {
                        anchors {
                            top:   parent.top
                            left:  parent.left
                            right: parent.right
                        }
                        spacing: 16

                        // Status
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: CaffeineState.active
                                  ? (CaffeineState.durationMinutes < 0
                                     ? "Preventing sleep indefinitely"
                                     : "Preventing sleep\n" + CaffeineState.remainingLabel + " remaining")
                                  : "Screen sleep allowed"
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            color: CaffeineState.active ? Theme.accent : Theme.fgDim
                            wrapMode: Text.WordWrap
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }

                        // Mode buttons grid
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            rowSpacing:    6
                            columnSpacing: 6

                            CaffeinePill { label: "Off";  isActive: !CaffeineState.active;                                     onActivated: CaffeineState.deactivate() }
                            CaffeinePill { label: "∞";    isActive: CaffeineState.active && CaffeineState.durationMinutes < 0; onActivated: CaffeineState.activateIndefinite() }
                            CaffeinePill {
                                label:    CaffeineState.active && CaffeineState.durationMinutes === 30 ? CaffeineState.remainingLabel : "30 min"
                                isActive: CaffeineState.active && CaffeineState.durationMinutes === 30
                                onActivated: CaffeineState.activateFor(30)
                            }
                            CaffeinePill {
                                label:    CaffeineState.active && CaffeineState.durationMinutes === 60 ? CaffeineState.remainingLabel : "1 hour"
                                isActive: CaffeineState.active && CaffeineState.durationMinutes === 60
                                onActivated: CaffeineState.activateFor(60)
                            }
                            CaffeinePill {
                                label:    CaffeineState.active && CaffeineState.durationMinutes === 120 ? CaffeineState.remainingLabel : "2 hours"
                                isActive: CaffeineState.active && CaffeineState.durationMinutes === 120
                                onActivated: CaffeineState.activateFor(120)
                            }
                        }
                    }
                }

                // Tab 2: Calendar
                Item {
                    anchors.fill: parent
                    visible: panelContent.activeTab === 2

                    CalendarView {
                        anchors {
                            top:   parent.top
                            left:  parent.left
                            right: parent.right
                        }
                    }
                }
            }

            // ── Bottom tab bar ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color:  Qt.rgba(0.70, 0.62, 0.86, 0.15)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                TabButton {
                    icon:      ""    // notifications
                    tabIndex:  0
                    activeTab: panelContent.activeTab
                    onSelect:  panelContent.activeTab = 0
                }
                TabButton {
                    icon:      ""    // coffee
                    tabIndex:  1
                    activeTab: panelContent.activeTab
                    onSelect:  panelContent.activeTab = 1
                }
                TabButton {
                    icon:      ""    // calendar_month
                    tabIndex:  2
                    activeTab: panelContent.activeTab
                    onSelect:  panelContent.activeTab = 2
                }
            }
        }
    }

    // ── Helper components ─────────────────────────────────────────────────
    component CaffeinePill: Rectangle {
        property string label
        property bool   isActive: false
        signal activated

        Layout.fillWidth: true
        implicitHeight: 36
        radius: Theme.pillRadius
        color:  _pm.containsMouse
                ? (isActive ? Qt.rgba(0.50, 0.35, 0.80, 0.80) : Theme.bgHover)
                : isActive
                  ? Qt.rgba(0.70, 0.62, 0.86, 0.28)
                  : Qt.rgba(1, 1, 1, 0.06)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors.centerIn: parent
            text:  label
            font.family:    Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            color: isActive ? Theme.accent : Theme.fgDim
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        MouseArea {
            id: _pm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked:    activated()
        }
    }

    component TabButton: Rectangle {
        property string icon
        property int    tabIndex
        property int    activeTab
        signal select

        readonly property bool _active: tabIndex === activeTab

        implicitWidth:  48
        implicitHeight: 36
        radius: Theme.pillRadius
        color:  _tbm.containsMouse
                ? Theme.bgHover
                : _active ? Qt.rgba(0.70, 0.62, 0.86, 0.14) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text:  icon
                font.family:    Theme.iconFamily
                font.pixelSize: Theme.iconSize + 2
                color: _active ? Theme.accent : Theme.fgDim
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // Active indicator dot
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width:  4; height: 4
                radius: 2
                color:  Theme.accent
                visible: _active
            }
        }

        MouseArea {
            id: _tbm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked:    parent.select()
        }
    }
}
