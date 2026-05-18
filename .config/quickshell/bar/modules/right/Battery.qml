// right/Battery.qml — UPower battery level + charging state
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import ".."

BarWidget {
    id: root

    property UPowerDevice bat: UPower.displayDevice

    property real percent:    bat ? Math.round(bat.percentage * 100) : 0
    property bool charging:   bat ? (bat.state === UPowerDeviceState.Charging
                                  || bat.state === UPowerDeviceState.FullyCharged
                                  || bat.state === UPowerDeviceState.PendingCharge) : false
    property bool full:       bat ? bat.state === UPowerDeviceState.FullyCharged : false

    function batteryIcon() {
        if (root.full || root.percent >= 98) return "\ue1a4"   // battery_full
        if (root.charging) {
            if (root.percent >= 80) return "\uebd4"            // battery_charging_80
            if (root.percent >= 60) return "\uebd2"            // battery_charging_60
            if (root.percent >= 40) return "\uebd0"            // battery_charging_40
            if (root.percent >= 20) return "\uebce"            // battery_charging_20
            return "\uebcc"                                     // battery_charging_20 (low)
        }
        if (root.percent >= 90) return "\ue1a4"                // battery_full
        if (root.percent >= 80) return "\ue1a3"                // battery_6_bar
        if (root.percent >= 60) return "\ue1a2"                // battery_5_bar
        if (root.percent >= 40) return "\ue1a1"                // battery_3_bar
        if (root.percent >= 20) return "\ue19e"                // battery_2_bar
        if (root.percent >= 10) return "\ue19d"                // battery_1_bar
        return "\ue19c"                                         // battery_0_bar
    }

    function batteryColor() {
        if (root.charging || root.full) return Theme.green
        if (root.percent <= 15)         return Theme.red
        if (root.percent <= 30)         return Theme.yellow
        return Theme.fg
    }

    content: RowLayout {
        spacing: 4

        Text {
            text:  root.batteryIcon()
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize
            color: root.hovered ? Theme.accent : root.batteryColor()
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            text:  root.percent + "%"
            font.family:    Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: root.batteryColor()
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }
}
