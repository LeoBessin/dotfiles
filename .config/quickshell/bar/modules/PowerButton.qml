// PowerButton.qml — power action button used inside the notification center settings tab
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "."

Rectangle {
    id: root

    property string icon:           ""
    property string label:          ""
    property color  iconColor:      Theme.fg
    property var    command:        []
    property bool   requireConfirm: false

    property bool _confirming: false

    implicitHeight: 52
    radius:         Theme.pillRadius

    color: _pm.containsMouse
           ? (_confirming
              ? Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.20)
              : Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.12))
           : (_confirming
              ? Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.12)
              : Qt.rgba(1, 1, 1, 0.06))
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    border.color: _confirming ? Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.50) : "transparent"
    border.width: 1
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    Timer {
        id: confirmReset
        interval: 3000
        onTriggered: root._confirming = false
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4

        Text {
            Layout.alignment: Qt.AlignHCenter
            text:             root.icon
            font.family:      Theme.iconFamily
            font.pixelSize:   Theme.iconSize
            color: _pm.containsMouse || root._confirming
                   ? root.iconColor
                   : Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.70)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text:             root._confirming ? "Confirm?" : root.label
            font.family:      Theme.fontFamily
            font.pixelSize:   Theme.fontSize - 1
            color: root._confirming ? root.iconColor : Theme.fgDim
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }

    MouseArea {
        id: _pm
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked: {
            if (root.requireConfirm && !root._confirming) {
                root._confirming = true
                confirmReset.restart()
            } else {
                root._confirming = false
                confirmReset.stop()
                execProc.running = false
                execProc.running = true
            }
        }
    }

    Process {
        id: execProc
        command: root.command
    }
}
