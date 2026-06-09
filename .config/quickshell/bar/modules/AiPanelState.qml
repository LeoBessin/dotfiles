pragma Singleton
import QtQuick

QtObject {
    property bool panelOpen:   false
    property var  targetScreen: null
    property int  activeTab:   0     // 0=AI Chat, 1=Translate, 2=Dictionary

    function togglePanel(screen) {
        if (panelOpen && targetScreen === screen) {
            closePanel()
        } else {
            targetScreen = screen
            panelOpen    = true
        }
    }

    function closePanel() {
        panelOpen = false
    }
}
