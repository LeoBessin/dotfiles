// left/DockerWidget.qml — docker.service status + start/stop + Portainer shortcut
// Left click opens Portainer (localhost:9001) when the service is running.
// Right click starts it immediately, or arms a confirm (click again within
// 3s) before stopping it. Both start and stop are gated behind the same
// sudo/howdy auth flow the TOTP vault uses.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."

BarWidget {
    id: root

    property bool _confirming: false

    function iconColor() {
        if (root._confirming) return Theme.red
        if (root.hovered)     return Theme.accent
        return Theme.fgDim
    }

    function dotColor() {
        if (DockerService.starting || DockerService.stopping) return Theme.yellow
        return Theme.green
    }

    Timer {
        id: confirmReset
        interval: 3000
        onTriggered: root._confirming = false
    }

    onClicked: {
        if (DockerService.running) {
            openProc.running = false
            openProc.running = true
        }
    }

    onRightClicked: {
        if (!DockerService.running) {
            root._confirming = false
            DockerService.requestStart()
        } else if (!root._confirming) {
            root._confirming = true
            confirmReset.restart()
        } else {
            root._confirming = false
            confirmReset.stop()
            DockerService.requestStop()
        }
    }

    Process {
        id: openProc
        command: ["xdg-open", "http://localhost:9001"]
    }

    content: RowLayout {
        spacing: 3

        Text {
            id: iconIndicator
            text: "deployed_code"
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize
            color: root.iconColor()
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            RotationAnimator on rotation {
                running:  DockerService.starting || DockerService.stopping
                from:     0
                to:       360
                duration: 1000
                loops:    Animation.Infinite
                onStopped: iconIndicator.rotation = 0
            }
        }

        Rectangle {
            visible: DockerService.running || DockerService.starting || DockerService.stopping
            width:  5; height: 5
            radius: 3
            color:  root.dotColor()
            opacity: 0.85
        }

        Text {
            visible: root._confirming
            text: "confirm?"
            font.family:    Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            color: Theme.red
        }
    }

    // ── Auth popup — same sudo/howdy flow as the TOTP vault ────────────────
    PopupWindow {
        id: authPopup
        visible:        DockerService.authenticating || DockerService.authError !== ""
        anchor.item:    root
        anchor.edges:   Edges.Bottom
        anchor.gravity: Edges.Bottom

        implicitWidth:  220
        implicitHeight: popupContent.implicitHeight + 24
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color:        Theme.bgPopup
            radius:       Theme.pillRadius
            border.color: Qt.rgba(0.70, 0.62, 0.86, 0.25)
            border.width: 1

            ColumnLayout {
                id: popupContent
                anchors.fill:    parent
                anchors.margins: 12
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: DockerService.authenticating
                          ? "Scanning your face… or enter your password"
                          : "Docker"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 30
                    radius: Theme.pillRadius
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: pwField.activeFocus ? Theme.notifBorderBase : Theme.notifBorderDim
                    border.width: 1

                    TextField {
                        id: pwField
                        anchors.fill: parent
                        anchors.margins: 2
                        echoMode: TextInput.Password
                        placeholderText: "Password…"
                        placeholderTextColor: Theme.fgDim
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                        background: null
                        padding: 6
                        onAccepted: {
                            DockerService.submitPassword(pwField.text)
                            pwField.text = ""
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    visible: DockerService.authError !== ""
                    text: DockerService.authError
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    color: Theme.red
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "cancel"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    color: cancelHov.containsMouse ? Theme.accent : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    MouseArea {
                        id: cancelHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pwField.text = ""
                            DockerService.cancelAuth()
                        }
                    }
                }
            }
        }
    }
}
