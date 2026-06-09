import QtQuick
import QtQuick.Layouts
import ".."

BarWidget {
    id: root

    property var barScreen

    onClicked: AiPanelState.togglePanel(barScreen)

    content: RowLayout {
        spacing: 3

        Text {
            text: "neurology"
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize
            color: root.hovered
                   ? Theme.accent
                   : AiPanelState.panelOpen && AiPanelState.targetScreen === root.barScreen
                     ? Theme.accent
                     : Theme.fgDim
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Rectangle {
            visible: LemonadeService.serverRunning
            width:  5; height: 5
            radius: 3
            color:  Theme.green
            opacity: 0.85
        }
    }
}
