// right/Network.qml — WiFi SSID, signal strength icon, tx/rx speed
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

BarWidget {
    id: root

    function fmtSpeed(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + "M"
        if (bps >= 1024)    return (bps / 1024).toFixed(0)    + "K"
        return bps.toFixed(0) + "B"
    }

    function wifiIcon() {
        if (!NetworkService.connected)          return ""
        if (NetworkService.signal >= 0.75)      return ""
        if (NetworkService.signal >= 0.50)      return ""
        if (NetworkService.signal >= 0.25)      return ""
        return ""
    }

    content: RowLayout {
        spacing: 4

        Text {
            text:           root.wifiIcon()
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize
            color: NetworkService.connected
                   ? (root.hovered ? Theme.accent : Theme.fg)
                   : Theme.fgDim
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Column {
            spacing: 0

            Text {
                text:           NetworkService.ssid
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                color:          Theme.fg
                elide:          Text.ElideRight
                width:          80
            }

            RowLayout {
                visible: NetworkService.connected
                spacing: 4

                Text {
                    text:           ""
                    font.family:    Theme.iconFamily
                    font.pixelSize: 10
                    color:          Theme.fgDim
                }
                Text {
                    text:           root.fmtSpeed(NetworkService.txSpeed)
                    font.family:    Theme.monoFamily
                    font.pixelSize: 9
                    color:          Theme.fgDim
                }
                Text {
                    text:           ""
                    font.family:    Theme.iconFamily
                    font.pixelSize: 10
                    color:          Theme.fgDim
                }
                Text {
                    text:           root.fmtSpeed(NetworkService.rxSpeed)
                    font.family:    Theme.monoFamily
                    font.pixelSize: 9
                    color:          Theme.fgDim
                }
            }
        }
    }
}
