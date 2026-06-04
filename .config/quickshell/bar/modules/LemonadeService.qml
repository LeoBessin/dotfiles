pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0; height: 0

    readonly property string baseUrl: "http://localhost:13305"
    property bool serverRunning: false
    property bool statusChecked: false
    property bool starting: false
    property bool stopping: false
    property ListModel models: ListModel {}

    // ── Public API ────────────────────────────────────────────────────────

    function refreshStatus() {
        statusProc.running = false
        statusProc.running = true
    }

    function refreshModels() {
        modelsProc._buf = ""
        modelsProc.running = false
        modelsProc.running = true
    }

    function startServer() {
        root.starting = true
        startProc.running = false
        startProc.running = true
    }

    function stopServer() {
        root.stopping = true
        stopProc.running = false
        stopProc.running = true
    }

    function isVisionModel(name) {
        var n = (name || "").toLowerCase()
        return /vision|llava|gemma3|minicpm.v|qwen.*vl|pixtral|phi.3.vision/.test(n)
    }

    // ── Status check ──────────────────────────────────────────────────────

    Process {
        id: statusProc
        command: ["lemonade", "status"]
        stdout: SplitParser {
            onRead: (line) => {
                if (line.includes("Server is running")) root.serverRunning = true
            }
        }
        onRunningChanged: {
            if (running) return
            root.statusChecked = true
            root.starting      = false
            if (root.serverRunning) root.refreshModels()
        }
        onExited: (code) => {
            if (code !== 0) root.serverRunning = false
        }
    }

    // ── Model list ────────────────────────────────────────────────────────

    Process {
        id: modelsProc
        property string _buf: ""
        command: ["curl", "-s", root.baseUrl + "/v1/models"]
        stdout: SplitParser {
            onRead: (line) => { modelsProc._buf += line }
        }
        onRunningChanged: {
            if (running) return
            try {
                var resp = JSON.parse(modelsProc._buf)
                root.models.clear()
                for (var i = 0; i < resp.data.length; i++)
                    root.models.append({ name: resp.data[i].id })
            } catch(e) {}
            modelsProc._buf = ""
        }
    }

    // ── Server start ──────────────────────────────────────────────────────

    Process {
        id: startProc
        command: ["sudo", "systemctl", "start", "lemond"]
        onExited: (code) => {
            if (code === 0) {
                root.serverRunning = true
                root.refreshModels()
            }
            root.starting = false
        }
    }

    // ── Server stop ───────────────────────────────────────────────────────

    Process {
        id: stopProc
        command: ["sudo", "systemctl", "stop", "lemond"]
        onExited: {
            root.serverRunning = false
            root.models.clear()
            root.stopping = false
        }
    }
}
