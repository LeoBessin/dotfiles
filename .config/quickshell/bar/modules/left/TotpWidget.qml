import QtQuick
import QtQuick.Layouts
import ".."

BarWidget {
    id: root

    property var barScreen

    onClicked: TotpVaultState.togglePanel(barScreen)

    content: Text {
        text: "key"
        font.family:    Theme.iconFamily
        font.pixelSize: Theme.iconSize
        color: root.hovered
               ? Theme.accent
               : TotpVaultState.panelOpen && TotpVaultState.targetScreen === root.barScreen
                 ? Theme.accent
                 : Theme.fgDim
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }
}
