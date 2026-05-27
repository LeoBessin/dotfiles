// left/IdleClock.qml — idle inhibitor toggle + clock
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."

Item {
    id: root
    implicitHeight: Theme.barHeight
    implicitWidth:  row.implicitWidth

    property var barWindow: null

    // ── Idle inhibitor state (shared across all bar instances) ────────────
    IdleInhibitor {
        id: idleInhibitor
        enabled: CaffeineState.active
        window:  root.barWindow
    }

    // ── Clock ─────────────────────────────────────────────────────────────
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── Layout: [inhibit btn] [clock widget] ─────────────────────────────
    RowLayout {
        id: row
        anchors.fill: parent
        spacing:      Theme.widgetSpacing

        // Idle inhibitor toggle button
        Item {
            id: inhibitBtn
            implicitWidth:  28
            implicitHeight: Theme.barHeight

            Rectangle {
                anchors.centerIn: parent
                width:  parent.width
                height: parent.height - 8
                radius: Theme.pillRadius
                color:  inhibitHover.containsMouse ? Theme.bgHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            Text {
                anchors.centerIn: parent
                text:  CaffeineState.active ? "󰅶" : "󰛊"
                // 󰛊 = nf-md-coffee (idle allowed), 󰅶 = nf-md-sleep (inhibit active)
                font.family:    Theme.monoFamily
                font.pixelSize: Theme.iconSize - 4
                color: CaffeineState.active ? Theme.accent : Theme.fgDim

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            MouseArea {
                id: inhibitHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked:    CaffeineState.active ? CaffeineState.deactivate() : CaffeineState.activateIndefinite()
            }
        }

        // Clock widget
        Item {
            id: clockWidget
            implicitWidth:  clockContent.implicitWidth + Theme.widgetPad * 2
            implicitHeight: Theme.barHeight

            Rectangle {
                anchors.centerIn: parent
                width:  parent.width
                height: parent.height - 8
                radius: Theme.pillRadius
                color:  clockHover.containsMouse ? Theme.bgHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            RowLayout {
                id: clockContent
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text:  "\ue8b5"
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
                anchors.fill: parent
                hoverEnabled: true
            }
        }
    }

}
