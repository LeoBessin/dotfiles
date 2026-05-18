// left/IdleClock.qml — idle inhibitor toggle + clock + calendar popup on hover
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."

Item {
    id: root
    implicitHeight: Theme.barHeight
    implicitWidth:  row.implicitWidth

    // ── Idle inhibitor state ──────────────────────────────────────────────
    property bool inhibitActive: false

    IdleInhibitor {
        id: idleInhibitor
        enabled: root.inhibitActive
    }

    // ── Clock ─────────────────────────────────────────────────────────────
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── Calendar popup ────────────────────────────────────────────────────
    property bool calendarVisible: false

    PopupWindow {
        id: calendarPopup
        visible:  root.calendarVisible
        anchor.item:    clockWidget
        anchor.edges:   Edges.Bottom
        anchor.gravity: Edges.Bottom

        implicitWidth:  260
        implicitHeight: calendarContent.implicitHeight + 16
        color:  "transparent"

        Rectangle {
            anchors.fill: parent
            color:        Theme.bgPopup
            radius:       Theme.radius
            border.color: Qt.rgba(0.70, 0.62, 0.86, 0.18)
            border.width: 1

            CalendarView {
                id: calendarContent
                anchors {
                    top:   parent.top
                    left:  parent.left
                    right: parent.right
                    topMargin: 8
                }
            }

            HoverHandler {
                onHoveredChanged: {
                    root._popupHovered = hovered
                    if (!hovered) hideTimer.restart()
                }
            }
        }
    }

    // ── Layout: [inhibit btn] [clock widget] ─────────────────────────────
    RowLayout {
        id: row
        anchors.fill: parent
        spacing:      Theme.widgetSpacing

        // Idle inhibitor toggle button
        Rectangle {
            id: inhibitBtn
            implicitWidth:  28
            implicitHeight: Theme.barHeight
            color:          inhibitHover.containsMouse ? Theme.bgHover : "transparent"
            radius:         Theme.pillRadius

            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Text {
                anchors.centerIn: parent
                text:  root.inhibitActive ? "󰅶" : "󰛊"
                // 󰛊 = nf-md-coffee (idle allowed), 󰅶 = nf-md-sleep (inhibit active)
                font.family:    Theme.monoFamily
                font.pixelSize: Theme.iconSize - 4
                color: root.inhibitActive ? Theme.accent : Theme.fgDim

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            MouseArea {
                id: inhibitHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked:    root.inhibitActive = !root.inhibitActive
            }
        }

        // Clock widget (hover shows calendar)
        Rectangle {
            id: clockWidget
            implicitWidth:  clockContent.implicitWidth + Theme.widgetPad * 2
            implicitHeight: Theme.barHeight
            color:          clockHover.containsMouse ? Theme.bgHover : "transparent"
            radius:         Theme.pillRadius

            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            RowLayout {
                id: clockContent
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text:  "\ue8b5"   // Material Symbols: schedule (clock)
                    font.family:    Theme.iconFamily
                    font.pixelSize: Theme.iconSize
                    color: clockHover.containsMouse ? Theme.accent : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Text {
                    text:  clock.date ? Qt.formatTime(clock.date, "h:mm ap") : "--:--"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight:    Font.Medium
                    color: Theme.fg
                }

                Text {
                    text:  clock.date ? Qt.formatDate(clock.date, "ddd dd MMM") : ""
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                }
            }

            MouseArea {
                id: clockHover
                anchors.fill:  parent
                hoverEnabled:  true
                cursorShape:   Qt.PointingHandCursor
                onEntered:     root.calendarVisible = true
                onExited:      {
                    // Delay hide so the popup itself can be hovered
                    hideTimer.restart()
                }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 150
        onTriggered: {
            if (!root._popupHovered)
                root.calendarVisible = false
        }
    }

    // alias so hideTimer can check it — toggled by HoverHandler on the popup
    property bool _popupHovered: false
}
