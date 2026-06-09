import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

    property bool isActive: AiPanelState.panelOpen &&
                            AiPanelState.targetScreen === modelData

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "quickshell-ai-panel"
    WlrLayershell.keyboardFocus: root.isActive
                                 ? WlrKeyboardFocus.OnDemand
                                 : WlrKeyboardFocus.None

    color: "transparent"
    surfaceFormat.opaque: false

    Component.onCompleted: exclusionMode = ExclusionMode.Ignore

    visible: false
    onVisibleChanged: if (!visible && root.isActive) AiPanelState.closePanel()

    onIsActiveChanged: {
        if (root.isActive) {
            root.visible = true
            hideTimer.stop()
            // Refresh server status every time panel opens
            LemonadeService.refreshStatus()
        } else {
            hideTimer.restart()
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
        onClicked: AiPanelState.closePanel()
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

        width: Theme.aiPanelWidth

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

                    // Icon
                    Text {
                        text: AiPanelState.activeTab === 0 ? "smart_toy"
                            : AiPanelState.activeTab === 1 ? "translate"
                            : "menu_book"
                        font.family:    Theme.iconFamily
                        font.pixelSize: 20
                        color: Theme.accent
                    }

                    // Title
                    Text {
                        Layout.fillWidth: true
                        text: AiPanelState.activeTab === 0 ? "AI Chat"
                            : AiPanelState.activeTab === 1 ? "Translate"
                            : "Dictionary"
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        font.weight:    Font.DemiBold
                        color: Theme.fg
                    }

                    // Tab switcher pills
                    Row {
                        spacing: 4

                        Repeater {
                            model: [
                                { label: "AI Chat",    icon: "smart_toy",  tab: 0 },
                                { label: "Translate",  icon: "translate",  tab: 1 },
                                { label: "Dictionary", icon: "menu_book",  tab: 2 }
                            ]
                            delegate: Rectangle {
                                property bool isTab: AiPanelState.activeTab === modelData.tab
                                width: tabLabel.implicitWidth + 16
                                height: 26
                                radius: Theme.pillRadius
                                color: isTab
                                       ? Qt.rgba(0.44, 0.39, 0.68, 0.35)
                                       : tabHov.containsMouse ? Theme.bgHover : "transparent"
                                border.color: isTab
                                              ? Qt.rgba(0.70, 0.62, 0.86, 0.35)
                                              : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    id: tabLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.family:    Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    color: isTab ? Theme.fg : Theme.fgDim
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }

                                MouseArea {
                                    id: tabHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: AiPanelState.activeTab = modelData.tab
                                }
                            }
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

                ChatView {
                    anchors.fill: parent
                    visible: AiPanelState.activeTab === 0
                    enabled: AiPanelState.activeTab === 0
                }

                TranslateView {
                    anchors.fill: parent
                    visible: AiPanelState.activeTab === 1
                    enabled: AiPanelState.activeTab === 1
                }

                DictionaryView {
                    anchors.fill: parent
                    visible: AiPanelState.activeTab === 2
                    enabled: AiPanelState.activeTab === 2
                }
            }
        }
    }
}
