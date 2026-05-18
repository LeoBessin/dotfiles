// right/Network.qml — WiFi SSID, signal strength icon, tx/rx speed
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import ".."

BarWidget {
    id: root

    // ── Networking singleton ──────────────────────────────────────────────
    property var wifiDev: {
        var devs = Networking.devices
        for (var i = 0; i < devs.values.length; i++) {
            var d = devs.values[i]
            if (d.type === DeviceType.Wifi)
                return d
        }
        return null
    }

    property var activeNet: {
        if (!wifiDev) return null
        var nets = wifiDev.networks
        for (var i = 0; i < nets.values.length; i++) {
            var n = nets.values[i]
            if (n.connected) return n
        }
        return null
    }
    property bool connected:  wifiDev ? wifiDev.connected : false
    property real signal:     activeNet ? activeNet.signalStrength : 0   // 0.0–1.0
    property string ssid:     activeNet ? activeNet.name : "offline"

    // ── TX/RX speed via /proc/net/dev ─────────────────────────────────────
    property string iface:   (wifiDev && wifiDev.name) ? wifiDev.name : ""
    property real   txBytes: 0
    property real   rxBytes: 0
    property real   txSpeed: 0   // bytes/s
    property real   rxSpeed: 0

    property var _prevTx: -1
    property var _prevRx: -1

    FileView {
        id: netStats
        path: "/proc/net/dev"
        onTextChanged: {
            if (!root.iface) return
            var lines = netStats.text().split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (!line.startsWith(root.iface + ":")) continue
                var parts = line.replace(/\s+/g, " ").split(" ")
                // Format: iface: rx_bytes ... tx_bytes ...
                // cols: 0=iface, 1=rx_bytes, 2-8=rx stats, 9=tx_bytes
                var rx = parseFloat(parts[1]) || 0
                var tx = parseFloat(parts[9]) || 0
                if (root._prevRx >= 0) {
                    root.rxSpeed = Math.max(0, rx - root._prevRx)
                    root.txSpeed = Math.max(0, tx - root._prevTx)
                }
                root._prevRx = rx
                root._prevTx = tx
                break
            }
        }
    }

    // Re-read every second
    Timer {
        interval: 1000
        running:  true
        repeat:   true
        onTriggered: netStats.reload()
    }

    function fmtSpeed(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + "M"
        if (bps >= 1024)    return (bps / 1024).toFixed(0)    + "K"
        return bps.toFixed(0) + "B"
    }

    function wifiIcon() {
        if (!root.connected) return "\ue648"         // wifi_off
        if (root.signal >= 0.75) return "\ue63e"     // wifi (full)
        if (root.signal >= 0.50) return "\ue1d9"     // wifi_2_bar
        if (root.signal >= 0.25) return "\ue1d8"     // wifi_1_bar
        return "\ue1da"                               // wifi_find (weak)
    }

    // ── Content ───────────────────────────────────────────────────────────
    content: RowLayout {
        spacing: 4

        Text {
            text:  root.wifiIcon()
            font.family:    Theme.iconFamily
            font.pixelSize: Theme.iconSize
            color: root.connected
                   ? (root.hovered ? Theme.accent : Theme.fg)
                   : Theme.fgDim
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Column {
            spacing: 0

            Text {
                text:  root.ssid
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                color: Theme.fg
                elide: Text.ElideRight
                width: 80
            }

            // Speed row — only when connected
            RowLayout {
                visible: root.connected
                spacing: 4

                Text {
                    text:  "\ue5db"   // arrow_upward (tiny)
                    font.family:    Theme.iconFamily
                    font.pixelSize: 10
                    color: Theme.fgDim
                }
                Text {
                    text:  root.fmtSpeed(root.txSpeed)
                    font.family:    Theme.monoFamily
                    font.pixelSize: 9
                    color: Theme.fgDim
                }
                Text {
                    text:  "\ue5d8"   // arrow_downward
                    font.family:    Theme.iconFamily
                    font.pixelSize: 10
                    color: Theme.fgDim
                }
                Text {
                    text:  root.fmtSpeed(root.rxSpeed)
                    font.family:    Theme.monoFamily
                    font.pixelSize: 9
                    color: Theme.fgDim
                }
            }
        }
    }
}
