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
            implicitWidth: CaffeineState.active && CaffeineState.durationMinutes > 0
                           ? iconText.implicitWidth + countdownText.implicitWidth + 4 + 8
                           : 28
            implicitHeight: Theme.barHeight
            Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast } }

            Rectangle {
                anchors.centerIn: parent
                width:  parent.width
                height: parent.height - 8
                radius: Theme.pillRadius
                color:  inhibitHover.containsMouse ? Theme.bgHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            Row {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    id: iconText
                    text: CaffeineState.active ? "󰅶" : "󰛊"
                    // 󰛊 = nf-md-coffee (idle allowed), 󰅶 = nf-md-sleep (inhibit active)
                    font.family:    Theme.monoFamily
                    font.pixelSize: Theme.iconSize - 4
                    color: CaffeineState.active ? Theme.accent : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Text {
                    id: countdownText
                    visible: CaffeineState.active && CaffeineState.durationMinutes > 0
                    text:    CaffeineState.remainingLabel
                    font.family:    Theme.monoFamily
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.accent
                }
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

            RowLayout {
                id: clockContent
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text:  "\ue8b5"
                    font.family:    Theme.iconFamily
                    font.pixelSize: Theme.iconSize
                    color: Theme.fgDim
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

        }
    }

}
