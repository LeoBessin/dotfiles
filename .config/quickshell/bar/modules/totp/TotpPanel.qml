import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."

PanelWindow {
    id: root

    property var modelData
    screen: modelData

    anchors.left:   true
    anchors.right:  true
    anchors.top:    true
    anchors.bottom: true

    property bool isActive: TotpVaultState.panelOpen &&
                            TotpVaultState.targetScreen === modelData

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "quickshell-totp-panel"
    WlrLayershell.keyboardFocus: root.isActive
                                 ? WlrKeyboardFocus.OnDemand
                                 : WlrKeyboardFocus.None

    color: "transparent"
    surfaceFormat.opaque: false

    // Blur only the card, not the fullscreen surface — see the background-effect
    // note in contrib/niri/config.kdl.
    BackgroundEffect.blurRegion: Region { item: panel; radius: Theme.radius }

    Component.onCompleted: exclusionMode = ExclusionMode.Ignore

    visible: false
    onVisibleChanged: if (!visible && root.isActive) TotpVaultState.closePanel()

    onIsActiveChanged: {
        if (root.isActive) {
            root.visible = true
            hideTimer.stop()
            if (TotpVaultState.unlocked) TotpVaultState.refreshCodes()
            else unlockView.beginAuth()
        } else {
            hideTimer.restart()
            unlockView.cancelAuth()
        }
    }

    Timer {
        id: hideTimer
        interval: Theme.animMed + 20
        onTriggered: root.visible = false
    }

    // ── Backdrop ──────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: TotpVaultState.closePanel()
    }

    // ── Slide-in panel (from left) ────────────────────────────────────────
    Rectangle {
        id: panel
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        anchors.left:       parent.left
        anchors.topMargin:  Theme.barHeight + 6
        anchors.bottomMargin: 6
        anchors.leftMargin: root.isActive ? 8 : -width

        width: Theme.totpPanelWidth

        opacity: root.isActive ? 1.0 : 0.0

        Behavior on anchors.leftMargin {
            NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.animFast }
        }

        color:        Theme.notifPanelBg
        radius:       Theme.radius
        border.color: Theme.notifBorderBase
        border.width: 1

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Header ────────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                height: 50

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 10

                    Text {
                        text: "key"
                        font.family:    Theme.iconFamily
                        font.pixelSize: 20
                        color: Theme.accent
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "TOTP Vault"
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        font.weight:    Font.DemiBold
                        color: Theme.fg
                    }

                    Text {
                        visible: TotpVaultState.unlocked
                        text: "lock"
                        font.family:    Theme.iconFamily
                        font.pixelSize: 18
                        color: lockHov.containsMouse ? Theme.accent : Theme.fgDim
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        MouseArea {
                            id: lockHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: TotpVaultState.lockVault()
                        }
                    }
                }
            }

            // Header divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.notifBorderDim
            }

            // ── Content area ──────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                UnlockView {
                    id: unlockView
                    anchors.fill: parent
                    visible: !TotpVaultState.unlocked
                    enabled: !TotpVaultState.unlocked
                }

                VaultView {
                    anchors.fill: parent
                    visible: TotpVaultState.unlocked
                    enabled: TotpVaultState.unlocked
                }
            }
        }
    }
}
