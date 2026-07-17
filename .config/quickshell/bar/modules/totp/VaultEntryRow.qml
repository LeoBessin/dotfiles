import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."

Rectangle {
    id: root

    property string entryId: ""
    property string label:   ""
    property string issuer:  ""
    property int    period:  30

    readonly property string code:      TotpVaultState.codes[entryId] || "------"
    readonly property int    remaining: period - (TotpVaultState.nowSec % period)

    property bool _confirmingDelete: false
    property bool _copied: false

    height: 56
    radius: Theme.pillRadius
    color: rowHov.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.03)
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Timer {
        id: confirmReset
        interval: 3000
        onTriggered: root._confirmingDelete = false
    }

    Timer {
        id: copyReset
        interval: 1200
        onTriggered: root._copied = false
    }

    Process { id: copyProc }

    MouseArea {
        id: rowHov
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            copyProc.command = ["sh", "-c", "printf '%s' " + JSON.stringify(root.code) + " | wl-copy"]
            copyProc.running = false
            copyProc.running = true
            root._copied = true
            copyReset.restart()
        }
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.label
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight:    Font.DemiBold
                color: Theme.fg
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: root.issuer !== ""
                text: root.issuer
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                color: Theme.fgDim
                elide: Text.ElideRight
            }
        }

        Text {
            text: root._copied ? "Copied!" : root.code
            font.family:    Theme.monoFamily
            font.pixelSize: 18
            font.weight:    Font.DemiBold
            color: root._copied ? Theme.green : Theme.fg
        }

        Text {
            text: root.remaining + "s"
            font.family:      Theme.fontFamily
            font.pixelSize:   Theme.fontSize - 2
            color: root.remaining <= 5 ? Theme.red : Theme.fgDim
            horizontalAlignment: Text.AlignRight
        }

        Text {
            text: root._confirmingDelete ? "check" : "delete"
            font.family:    Theme.iconFamily
            font.pixelSize: 16
            color: root._confirmingDelete ? Theme.red : (delHov.containsMouse ? Theme.red : Theme.fgDim)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            MouseArea {
                id: delHov
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root._confirmingDelete) {
                        TotpVaultState.deleteEntry(root.entryId)
                    } else {
                        root._confirmingDelete = true
                        confirmReset.restart()
                    }
                }
            }
        }
    }
}
