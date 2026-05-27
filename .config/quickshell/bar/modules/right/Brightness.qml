// right/Brightness.qml — backlight control via brightnessctl
// Scroll to change, click to toggle between 30% and 100%.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

BarWidget {
    id: root

    function brightnessIcon() {
        if (BrightnessService.percent < 25) return ""
        if (BrightnessService.percent < 60) return ""
        return ""
    }

    onClicked: BrightnessService.setPercent(BrightnessService.percent > 50 ? 30 : 100)
    onScrolled: (delta) => BrightnessService.setPercent(
        Math.round(BrightnessService.percent) + (delta > 0 ? 5 : -5))

    content: RowLayout {
        spacing: 4

        Text {
            text:           root.brightnessIcon()
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize
            color:          root.hovered ? Theme.accent : Theme.fgDim
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            text:           Math.round(BrightnessService.percent) + "%"
            font.family:    Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color:          Theme.fg
        }
    }
}
