import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "."

Rectangle {
    id: root

    property int    notifId
    property string appName
    property string appIcon
    property string image
    property string summary
    property string body
    property string timeStr
    property string actionsJson
    property bool   hasDefault
    property bool   read
    property bool   dismissed

    signal dismissRequested
    signal readRequested

    implicitWidth:  360
    implicitHeight: itemRow.implicitHeight + 16
    radius: Theme.pillRadius
    clip:   true
    color:  itemMouse.containsMouse
            ? Theme.bgHover
            : read
              ? Qt.rgba(0.10, 0.10, 0.18, 0.50)
              : Qt.rgba(0.18, 0.16, 0.30, 0.80)

    border.color: read
        ? Qt.rgba(0.70, 0.62, 0.86, 0.08)
        : Qt.rgba(0.70, 0.62, 0.86, 0.22)
    border.width: 1

    Behavior on color        { ColorAnimation { duration: Theme.animFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    // Left unread accent stripe
    Rectangle {
        visible: !root.read
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width:  3
        radius: 2
        color:  Theme.accent
    }

    MouseArea {
        id: itemMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onEntered: { if (!root.read) readTimer.restart() }
        onExited:  readTimer.stop()
        onClicked: {
            if (!root.read) root.readRequested()
            if (root.hasDefault) {
                var ref = NotifService._liveRefs[root.notifId]
                try {
                    if (ref) {
                        for (var i = 0; i < ref.actions.length; i++) {
                            if (ref.actions[i].identifier === "default") {
                                ref.actions[i].invoke()
                                break
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: readTimer
        interval: 600
        onTriggered: root.readRequested()
    }

    // ── Content ───────────────────────────────────────────────────────────
    RowLayout {
        id: itemRow
        anchors {
            top:   parent.top
            left:  parent.left
            right: parent.right
            topMargin:    8
            bottomMargin: 8
            leftMargin:  12
            rightMargin:  8
        }
        spacing: 10

        // App icon — large, left column
        Rectangle {
            width:  36
            height: 36
            radius: 8
            color:  Qt.rgba(0.18, 0.16, 0.30, 0.60)
            Layout.alignment: Qt.AlignTop
            clip: true

            // Notification image (e.g. avatar, album art)
            Image {
                anchors.fill: parent
                source:     root.image
                visible:    root.image !== ""
                fillMode:   Image.PreserveAspectCrop
                smooth:     true
                mipmap:     true
            }

            // App icon when no notification image
            IconImage {
                anchors.centerIn: parent
                source:      root.image === "" && root.appIcon !== ""
                             ? (root.appIcon.startsWith("/") ? "file://" + root.appIcon : root.appIcon.startsWith("image://") ? root.appIcon : "image://icon/" + root.appIcon)
                             : ""
                implicitSize: 24
                visible: root.image === "" && root.appIcon !== ""
            }

            // Fallback glyph when neither image nor icon
            Text {
                anchors.centerIn: parent
                visible: root.image === "" && root.appIcon === ""
                text:  ""
                font.family:    Theme.iconFamily
                font.pixelSize: 20
                color: Theme.fgDim
            }
        }

        // Text content
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            // App name + time + dismiss
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text:  root.appName
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    font.weight:    Font.Medium
                    color: root.read ? Theme.fgDim : Theme.accent
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Text {
                    text:  root.timeStr
                    font.family:    Theme.monoFamily
                    font.pixelSize: Theme.fontSize - 3
                    color: Theme.fgDim
                }

                // Dismiss X
                Rectangle {
                    id: dismissBtn
                    width: 18; height: 18
                    radius: 9
                    color:  dismissMouse.containsMouse ? Theme.red : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text:  ""
                        font.family:    Theme.iconFamily
                        font.pixelSize: 12
                        color: dismissMouse.containsMouse ? Theme.bgSolid : Theme.fgDim
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    MouseArea {
                        id: dismissMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            mouse.accepted = true
                            root.dismissRequested()
                        }
                    }
                }
            }

            // Summary
            Text {
                text:  root.summary
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight:    Font.DemiBold
                color: root.read ? Theme.fgDim : Theme.fg
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // Body
            Text {
                visible: root.body !== ""
                text:    root.body
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                color:  Theme.fgDim
                linkColor: Theme.accent
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide:  Text.ElideRight
                Layout.fillWidth: true
            }

            // Action buttons
            RowLayout {
                id: actionsRow
                spacing: 6
                visible: _parsedActions.length > 0

                property var _parsedActions: {
                    try { return JSON.parse(root.actionsJson || "[]").slice(0, 2) }
                    catch(e) { return [] }
                }

                Repeater {
                    model: actionsRow._parsedActions

                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth:  actionLabel.implicitWidth + 12
                        implicitHeight: 20
                        radius: Theme.pillRadius
                        color:  actionMouse.containsMouse
                                ? Theme.accentDim
                                : Qt.rgba(0.70, 0.62, 0.86, 0.15)
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text:  modelData.text
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            color: Theme.accent
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                mouse.accepted = true
                                var actionId = modelData.id
                                var ref = NotifService._liveRefs[root.notifId]
                                try {
                                    if (ref) {
                                        for (var i = 0; i < ref.actions.length; i++) {
                                            if (ref.actions[i].identifier === actionId) {
                                                ref.actions[i].invoke()
                                                break
                                            }
                                        }
                                    }
                                } catch(e) {}
                                root.dismissRequested()
                            }
                        }
                    }
                }
            }
        }
    }
}
