import QtQuick
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
        implicitHeight: col.height + 16

        x: root.appeared && !root.dismissing ? 0 : width + 10
        Behavior on x {
            NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
        }

        opacity: root.dismissing ? 0.0 : 1.0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animMed }
        }

        radius:       Theme.pillRadius
        color:        Theme.bgPopup
        border.color: Qt.rgba(0.70, 0.62, 0.86, 0.25)
        border.width: 1

        Rectangle {
            anchors.left:   parent.left
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:  3
            radius: 2
            color:  Theme.accent
        }

        // Notification image thumbnail (right side)
        Rectangle {
            id: imgThumb
            visible: root.image !== ""
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 8
            width:  48
            radius: 6
            clip:   true
            color:  "transparent"

            Image {
                anchors.fill: parent
                source:     root.image
                fillMode:   Image.PreserveAspectCrop
                smooth:     true
                mipmap:     true
            }
        }

        Column {
            id: col
            anchors.top:   parent.top
            anchors.left:  parent.left
            anchors.right: root.image !== "" ? imgThumb.left : parent.right
            anchors.topMargin:   8
            anchors.leftMargin:  12
            anchors.rightMargin: root.image !== "" ? 4 : 8
            spacing: 4

            // Header: app name | icon | time | dismiss
            Item {
                width:  parent.width
                height: 18

                Text {
                    id: appNameText
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right:          appIcon.visible ? appIcon.left : timeText.left
                    anchors.rightMargin:    6
                    text:           root.appName
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    font.weight:    Font.Medium
                    color:          Theme.accent
                    elide:          Text.ElideRight
                }

                Image {
                    id: appIcon
                    anchors.right:          timeText.left
                    anchors.rightMargin:    6
                    anchors.verticalCenter: parent.verticalCenter
                    source:     root.appIcon.startsWith("/") ? "file://" + root.appIcon : root.appIcon.startsWith("image://") ? root.appIcon : (root.appIcon !== "" ? "image://icon/" + root.appIcon : "")
                    visible:    root.appIcon !== ""
                    width:  14; height: 14
                    sourceSize: Qt.size(14, 14)
                    fillMode:   Image.PreserveAspectFit
                    smooth:     true
                }

                Text {
                    id: timeText
                    anchors.right:          dismissBtn.left
                    anchors.rightMargin:    6
                    anchors.verticalCenter: parent.verticalCenter
                    text:           root.timeStr
                    font.family:    Theme.monoFamily
                    font.pixelSize: Theme.fontSize - 3
                    color:          Theme.fgDim
                }

                Rectangle {
                    id: dismissBtn
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18; radius: 9
                    color: xMouse.containsMouse ? Theme.red : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text:           ""
                        font.family:    Theme.iconFamily
                        font.pixelSize: 12
                        color: xMouse.containsMouse ? Theme.bgSolid : Theme.fgDim
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
                width:          parent.width
                text:           root.summary
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight:    Font.DemiBold
                color:          Theme.fg
                wrapMode:       Text.WordWrap
            }

            // Body
            Text {
                width:            parent.width
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
            Row {
                id: actionsRow
                spacing: 6
                visible: _acts.length > 0
                bottomPadding: 4

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
