import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import ".."

Item {
    id: root

    property bool authenticating: false
    property string authError:    ""

    // sudo is already wired to try face recognition (howdy) first, falling
    // back to the normal password prompt via PAM — `-k` forces a fresh
    // check every time instead of reusing a cached sudo ticket.
    function beginAuth() {
        authError       = ""
        authenticating  = true
        passwordField.text = ""
        authProc.running = false
        authProc.command = ["sudo", "-k", "-S", "-v"]
        authProc.stdinEnabled = true
        authProc.running = true
    }

    function cancelAuth() {
        authProc.running = false
        authenticating = false
    }

    function submitPassword() {
        var pw = passwordField.text
        if (!authenticating) beginAuth()
        authProc.write(pw + "\n")
        passwordField.text = ""
    }

    Process {
        id: authProc
        stdinEnabled: true
        onExited: (code, status) => {
            root.authenticating = false
            if (code === 0) {
                root.authError = ""
                TotpVaultState.unlockVault()
            } else {
                root.authError = "Authentication failed — try again"
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 260)
        spacing: 16

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "key"
            font.family:    Theme.iconFamily
            font.pixelSize: 44
            color: Theme.accent
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.authenticating
                  ? "Scanning your face… or enter your password"
                  : "Vault locked"
            font.family:    Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgDim
        }

        Rectangle {
            Layout.fillWidth: true
            height: 34
            radius: Theme.pillRadius
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: passwordField.activeFocus ? Theme.notifBorderBase : Theme.notifBorderDim
            border.width: 1

            TextField {
                id: passwordField
                anchors.fill: parent
                anchors.margins: 2
                echoMode: TextInput.Password
                placeholderText: "Password…"
                placeholderTextColor: Theme.fgDim
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.fg
                background: null
                padding: 8
                onAccepted: root.submitPassword()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 34
            radius: Theme.pillRadius
            color: unlockHov.containsMouse ? Theme.accentDim : Theme.accent
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Text {
                anchors.centerIn: parent
                text: "Unlock"
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.bgSolid
            }

            MouseArea {
                id: unlockHov
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.submitPassword()
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: root.authError !== ""
            text: root.authError
            font.family:    Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            color: Theme.red
        }
    }
}
