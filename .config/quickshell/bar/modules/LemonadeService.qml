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
    property string loadedModel: ""
    property bool loadingModel: false

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

    function loadModel(name) {
        root.loadingModel = true
        loadProc.command = ["lemonade", "load", name]
        loadProc.running = false
        loadProc.running = true
    }

    function isVisionModel(name) {
        var n = (name || "").toLowerCase()
        return /vision|llava|gemma3|minicpm.v|qwen.*vl|pixtral|phi.3.vision/.test(n)
    }

    // ── Model load ────────────────────────────────────────────────────────

    Process {
        id: loadProc
        onExited: (code) => {
            root.loadingModel = false
            if (code === 0) root.refreshStatus()
        }
    }

    // ── Status check ──────────────────────────────────────────────────────

    Process {
        id: statusProc
        property bool _pastSeparator: false
        property bool _foundModel: false
        command: ["lemonade", "status"]
        stdout: SplitParser {
            onRead: (line) => {
                var t = line.trim()
                if (line.includes("Server is running")) root.serverRunning = true
                if (t === "No models loaded.") { root.loadedModel = ""; statusProc._foundModel = true; return }
                // Properties table separator is ~50 dashes; model table separator is ~100 — only the longer one triggers
                if (/^-{60,}$/.test(t)) { statusProc._pastSeparator = true; return }
                if (statusProc._pastSeparator && t !== "") {
                    root.loadedModel = t.split(/\s+/)[0]
                    statusProc._foundModel = true
                    statusProc._pastSeparator = false
                }
            }
        }
        onRunningChanged: {
            if (running) { _pastSeparator = false; _foundModel = false; return }
            if (!_foundModel) root.loadedModel = ""
            root.statusChecked = true
            root.starting      = false
            if (root.serverRunning) root.refreshModels()
        }
        onExited: (code) => {
            if (code !== 0) { root.serverRunning = false; root.loadedModel = "" }
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
            root.loadedModel   = ""
            root.models.clear()
            root.stopping = false
        }
    }

}
