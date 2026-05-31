pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var wifiDev: {
        var devs = Networking.devices
        for (var i = 0; i < devs.values.length; i++) {
            if (devs.values[i].type === DeviceType.Wifi)
                return devs.values[i]
        }
        return null
    }

    property var    activeNet: {
        if (!wifiDev) return null
        var nets = wifiDev.networks
        for (var i = 0; i < nets.values.length; i++) {
            if (nets.values[i].connected) return nets.values[i]
        }
        return null
    }
    property bool   connected: wifiDev ? wifiDev.connected : false
    property real   signal:    activeNet ? activeNet.signalStrength : 0
    property string ssid:      activeNet ? activeNet.name : "offline"
    property string iface:     (wifiDev && wifiDev.name) ? wifiDev.name : ""

    property real txSpeed: 0
    property real rxSpeed: 0
    property var  _prevTx: -1
    property var  _prevRx: -1

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

    Timer {
        interval: 1000
        running:  true
        repeat:   true
        onTriggered: netStats.reload()
    }
}
