// PowerButton.qml — reusable button row used inside the power popup
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "."

Rectangle {
    id: root

    property string icon:    ""
    property string label:   ""
    property color  iconColor: Theme.fg
    property var    command: []

    signal activated

    implicitWidth:  parent ? parent.width : 140
    implicitHeight: 32
    radius:         Theme.pillRadius
    color:          btnHover.containsMouse ? Theme.bgHover : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    RowLayout {
        anchors.fill:        parent
        anchors.leftMargin:  8
        anchors.rightMargin: 8
        spacing: 8

        Text {
            text:  root.icon
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize
            color: root.iconColor
        }

        Text {
            text:  root.label
            font.family:    Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: root.iconColor
        }
    }

    MouseArea {
        id: btnHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked: {
            execProc.command = root.command
            execProc.running = true
            root.activated()
        }
    }

    Process {
        id: execProc
        command: root.command
    }
}
