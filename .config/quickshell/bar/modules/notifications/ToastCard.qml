import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root

    property int    notifId
    property string appName
    property string appIcon
    property string image
    property string summary
    property string body
    property string timeStr
    property string actionsJson

    signal expired
    signal dismissRequested

    implicitWidth:  card.width
    implicitHeight: card.implicitHeight
    clip: false

    property bool appeared:  false
    property bool dismissing: false

    Component.onCompleted: {
        appeared = true
        dismissTimer.start()
    }

    function startDismiss() {
        if (dismissing) return
        dismissing = true
        exitTimer.start()
    }

    Timer {
        id: exitTimer
        interval: Theme.animMed + 20
        onTriggered: root.expired()
    }

    Timer {
        id: dismissTimer
        interval: Theme.toastDuration
        onTriggered: root.startDismiss()
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: dismissTimer.stop()
        onExited:  if (!root.dismissing) dismissTimer.restart()
    }

    Rectangle {
        id: card
        width: Theme.notifCardWidth
        implicitHeight: itemRow.implicitHeight + 16

        x: root.appeared && !root.dismissing ? 0 : width + 10
        Behavior on x {
            NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
        }

        opacity: root.dismissing ? 0.0 : 1.0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animMed }
        }

        radius:       Theme.pillRadius
        color:        Theme.notifPanelBg
        border.color: Theme.notifUnreadBorder
        border.width: 1

        // Left accent stripe
        Rectangle {
            anchors.left:   parent.left
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:  3
            radius: 2
            color:  Theme.accent
        }

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

            // App icon / notification image box
            Rectangle {
                width:  Theme.notifIconBoxSize
                height: Theme.notifIconBoxSize
                radius: 8
                color:  Theme.notifIconBg
                Layout.alignment: Qt.AlignTop
                clip: true

                Image {
                    anchors.fill: parent
                    source:     root.image
                    visible:    root.image !== ""
                    fillMode:   Image.PreserveAspectCrop
                    smooth:     true
                    mipmap:     true
                }

                Image {
                    anchors.centerIn: parent
                    source:      root.image === "" && root.appIcon !== ""
                                 ? (root.appIcon.startsWith("/") ? "file://" + root.appIcon
                                    : root.appIcon.startsWith("image://") ? root.appIcon
                                    : "image://icon/" + root.appIcon)
                                 : ""
                    visible:     root.image === "" && root.appIcon !== ""
                    width:  24; height: 24
                    sourceSize: Qt.size(24, 24)
                    fillMode:   Image.PreserveAspectFit
                    smooth:     true
                    mipmap:     true
                }

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

                // Header: app name | time | dismiss
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text:           root.appName
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        font.weight:    Font.Medium
                        color:          Theme.accent
                        elide:          Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text:           root.timeStr
                        font.family:    Theme.monoFamily
                        font.pixelSize: Theme.fontSize - 3
                        color:          Theme.fgDim
                    }

                    Rectangle {
                        id: dismissBtn
                        width: 18; height: 18
                        radius: 9
                        color: xMouse.containsMouse ? Theme.red : Theme.notifBorderMid
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text:           ""
                            font.family:    Theme.iconFamily
                            font.pixelSize: 14
                            color: xMouse.containsMouse ? Theme.bgSolid : Theme.fg
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }

                        MouseArea {
                            id: xMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                mouse.accepted = true
                                root.startDismiss()
                                root.dismissRequested()
                            }
                        }
                    }
                }

                // Summary
                Text {
                    Layout.fillWidth: true
                    text:           root.summary
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight:    Font.DemiBold
                    color:          Theme.fg
                    wrapMode:       Text.WordWrap
                }

                // Body
                Text {
                    Layout.fillWidth: true
                    visible:          root.body !== ""
                    text:             root.body
                    font.family:      Theme.fontFamily
                    font.pixelSize:   Theme.fontSize - 1
                    color:            Theme.fgDim
                    linkColor:        Theme.accent
                    wrapMode:         Text.WordWrap
                    maximumLineCount: 2
                    elide:            Text.ElideRight
                }

                // Action buttons
                RowLayout {
                    id: actionsRow
                    spacing: 6
                    visible: _acts.length > 0

                    property var _acts: {
                        try { return JSON.parse(root.actionsJson || "[]").slice(0, 2) }
                        catch(e) { return [] }
                    }

                    Repeater {
                        model: actionsRow._acts
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth:  lbl.implicitWidth + 12
                            implicitHeight: 20
                            radius: Theme.pillRadius
                            color:  aMouse.containsMouse
                                    ? Theme.accentDim
                                    : Theme.notifBorderMid
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                id: lbl
                                anchors.centerIn: parent
                                text:           modelData.text
                                font.family:    Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                color:          Theme.accent
                            }

                            MouseArea {
                                id: aMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    mouse.accepted = true
                                    var ref = NotifService._liveRefs[root.notifId]
                                    try {
                                        if (ref) {
                                            for (var i = 0; i < ref.actions.length; i++) {
                                                if (ref.actions[i].identifier === modelData.id) {
                                                    ref.actions[i].invoke()
                                                    break
                                                }
                                            }
                                        }
                                    } catch(e) {}
                                    root.startDismiss()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
