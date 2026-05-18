// CalendarView.qml — compact month calendar widget used in the clock popup
import QtQuick
import QtQuick.Layouts
import "."

Item {
    id: root
    implicitWidth:  parent ? parent.width : 260
    implicitHeight: col.implicitHeight

    property var  today:       new Date()
    property int  viewYear:    today.getFullYear()
    property int  viewMonth:   today.getMonth()   // 0–11

    // Helper: days in a month
    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate()
    }
    // Helper: weekday of first day of month (0=Sun…6=Sat), shift to Mon-start
    function firstWeekday(year, month) {
        var d = new Date(year, month, 1).getDay()
        return (d + 6) % 7  // Mon=0 … Sun=6
    }

    readonly property var monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    readonly property var dayNames: ["Mo","Tu","We","Th","Fr","Sa","Su"]

    Column {
        id: col
        width: parent.width
        spacing: 4

        // ── Header: prev / month-year / next ─────────────────────────────
        RowLayout {
            width:  parent.width
            height: 28

            // Prev month
            Rectangle {
                width: 28; height: 28
                radius: Theme.pillRadius
                color: prevHover.containsMouse ? Theme.bgHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text:  "\ue5cb"   // chevron_left
                    font.family:    Theme.iconFamily
                    font.pixelSize: 18
                    color: Theme.fgDim
                }
                MouseArea {
                    id: prevHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        if (root.viewMonth === 0) { root.viewMonth = 11; root.viewYear-- }
                        else root.viewMonth--
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text:  root.monthNames[root.viewMonth] + " " + root.viewYear
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight:    Font.Medium
                color: Theme.fg
            }

            // Next month
            Rectangle {
                width: 28; height: 28
                radius: Theme.pillRadius
                color: nextHover.containsMouse ? Theme.bgHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text:  "\ue5cc"   // chevron_right
                    font.family:    Theme.iconFamily
                    font.pixelSize: 18
                    color: Theme.fgDim
                }
                MouseArea {
                    id: nextHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        if (root.viewMonth === 11) { root.viewMonth = 0; root.viewYear++ }
                        else root.viewMonth++
                    }
                }
            }
        }

        // ── Day-of-week header row ────────────────────────────────────────
        Row {
            width:   parent.width
            spacing: 0

            Repeater {
                model: root.dayNames
                delegate: Text {
                    width:  Math.floor(col.width / 7)
                    horizontalAlignment: Text.AlignHCenter
                    text:  modelData
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    color: Theme.fgDim
                }
            }
        }

        // Thin separator
        Rectangle {
            width:  parent.width
            height: 1
            color:  Qt.rgba(1,1,1,0.08)
        }

        // ── Day grid ─────────────────────────────────────────────────────
        Grid {
            id: dayGrid
            width:   parent.width
            columns: 7

        property int  totalCells: root.firstWeekday(root.viewYear, root.viewMonth)
                                + root.daysInMonth(root.viewYear, root.viewMonth)
            // Round up to full weeks
            property int  cellCount:  Math.ceil(totalCells / 7) * 7
            property int  cellW:      Math.floor(width / 7)
            property int  cellH:      22
            property int  startOffset: root.firstWeekday(root.viewYear, root.viewMonth)
            property int  numDays:     root.daysInMonth(root.viewYear, root.viewMonth)

            Repeater {
                model: dayGrid.cellCount

                delegate: Item {
                    width:  dayGrid.cellW
                    height: dayGrid.cellH

                    property int offset: index - dayGrid.startOffset
                    property int dayNum: offset + 1
                    property bool inMonth: offset >= 0 && dayNum <= dayGrid.numDays
                    property bool isToday: inMonth
                        && dayNum === root.today.getDate()
                        && root.viewMonth === root.today.getMonth()
                        && root.viewYear  === root.today.getFullYear()

                    Rectangle {
                        anchors.centerIn: parent
                        width:  20; height: 20
                        radius: 10
                        color:  isToday ? Theme.accent : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text:  inMonth ? dayNum : ""
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        font.weight:    isToday ? Font.Bold : Font.Normal
                        color: isToday  ? Theme.bgSolid
                             : inMonth  ? Theme.fg
                             : "transparent"
                    }
                }
            }
        }
    }
}
