import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import ".."

Item {
    id: root

    property bool streaming: false
    property string currentModel: ""
    property string attachedFilePath: ""
    property string attachedFileBase64: ""
    property bool showFileInput: false

    property ListModel messages: ListModel {}

    readonly property string _sessionPath: "/home/nexus/.local/share/quickshell/ai_session.json"
    property bool _sessionLoaded: false

    function _maybeAutoLoad() {
        if (!_sessionLoaded) return
        if (!LemonadeService.serverRunning) return
        if (LemonadeService.loadedModel !== "") return
        if (currentModel === "") return
        LemonadeService.loadModel(currentModel)
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────
    Component.onCompleted: {
        LemonadeService.refreshStatus()
        if (LemonadeService.loadedModel !== "")
            currentModel = LemonadeService.loadedModel
        sessionReadProc.command = ["cat", root._sessionPath]
        sessionReadProc.running = true
    }

    // Always follow the loaded model; also trigger auto-load after status check
    Connections {
        target: LemonadeService
        function onLoadedModelChanged() {
            if (LemonadeService.loadedModel !== "")
                root.currentModel = LemonadeService.loadedModel
        }
        function onServerRunningChanged() {
            if (LemonadeService.serverRunning) root._maybeAutoLoad()
        }
    }

    // ── Markdown segment parser ───────────────────────────────────────────
    function parseSegments(text) {
        var segments = []
        var parts = text.split("```")
        for (var i = 0; i < parts.length; i++) {
            if (i % 2 === 0) {
                if (parts[i].length > 0)
                    segments.push({ type: "text", content: parts[i] })
            } else {
                var lines = parts[i].split('\n')
                var code = lines.slice(1).join('\n')
                if (code.charAt(code.length - 1) === '\n')
                    code = code.slice(0, -1)
                segments.push({ type: "code", lang: lines[0].trim(), content: code })
            }
        }
        return segments
    }

    // ── Send message ──────────────────────────────────────────────────────
    function sendMessage() {
        var input = inputArea.text.trim()
        if (!input || streaming) return
        if (!LemonadeService.serverRunning) return

        var hasFile = attachedFilePath && attachedFileBase64 &&
                      LemonadeService.isVisionModel(currentModel)
        var userContent = hasFile
            ? JSON.stringify([
                { type: "text", text: input },
                { type: "image_url", image_url: { url: "data:image/jpeg;base64," + attachedFileBase64 } }
              ])
            : input

        var apiMessages = []
        apiMessages.push({ role: "system", content: "You are a concise assistant. Answer directly and briefly — one to three sentences unless detail is required. Use fenced code blocks (```) for all code, commands, and file paths. Skip preamble, affirmations, and restatements of the question." })
        for (var i = 0; i < messages.count; i++) {
            var m = messages.get(i)
            var raw = m.raw || m.content
            var parsed = raw
            try { parsed = JSON.parse(raw) } catch(e) {}
            apiMessages.push({ role: m.role, content: parsed })
        }
        apiMessages.push({ role: "user", content: hasFile ? JSON.parse(userContent) : input })

        messages.append({ role: "user", content: input, raw: userContent })
        messages.append({ role: "assistant", content: "", raw: "" })
        var assistantIdx = messages.count - 1

        inputArea.text     = ""
        attachedFilePath   = ""
        attachedFileBase64 = ""
        showFileInput      = false
        streaming          = true
        _chatAssistantIdx  = assistantIdx
        _chatFullContent   = ""
        Qt.callLater(() => msgView.positionViewAtEnd())

        var bodyJson = JSON.stringify({ model: currentModel, messages: apiMessages, stream: true })
                           .replace(/'/g, "\\u0027")

        chatProc.running = false
        chatProc.command = ["sh", "-c",
            "curl -s -N -X POST '" + LemonadeService.baseUrl + "/v1/chat/completions' " +
            "-H 'Content-Type: application/json' " +
            "-d '" + bodyJson + "'"
        ]
        chatProc.running = true
    }

    // ── Chat streaming (curl SSE) ─────────────────────────────────────────
    property int    _chatAssistantIdx: -1
    property string _chatFullContent:  ""

    Process {
        id: chatProc
        stdout: SplitParser {
            onRead: (line) => {
                var l = line.trim()
                if (!l.startsWith("data: ")) return
                var data = l.substring(6)
                if (data === "[DONE]") return
                try {
                    var delta = JSON.parse(data).choices[0].delta.content
                    if (delta) {
                        root._chatFullContent += delta
                        root.messages.setProperty(root._chatAssistantIdx, "content", root._chatFullContent)
                        root.messages.setProperty(root._chatAssistantIdx, "raw",     root._chatFullContent)
                        Qt.callLater(() => msgView.positionViewAtEnd())
                    }
                } catch(e) {}
            }
        }
        onRunningChanged: {
            if (running) return
            root.streaming = false
            if (root._chatAssistantIdx >= 0 && root._chatFullContent === "") {
                root.messages.setProperty(root._chatAssistantIdx, "content", "(no response)")
                root.messages.setProperty(root._chatAssistantIdx, "raw",     "(no response)")
            }
            root._chatAssistantIdx = -1
            Qt.callLater(() => msgView.positionViewAtEnd())
            root.saveSession()
        }
    }

    // ── File reading ──────────────────────────────────────────────────────
    Process {
        id: base64Proc
        property string _buf: ""
        stdout: SplitParser {
            onRead: (line) => { base64Proc._buf += line.trim() }
        }
        onRunningChanged: {
            if (!running && _buf) {
                root.attachedFileBase64 = _buf
                _buf = ""
            }
        }
    }

    function readFileAsBase64(path) {
        base64Proc._buf = ""
        base64Proc.command = ["sh", "-c", "base64 -w0 \"" + path.replace(/"/g, '\\"') + "\""]
        base64Proc.running = false
        base64Proc.running = true
    }

    // ── Session persistence ───────────────────────────────────────────────
    Process {
        id: sessionReadProc
        property string _buf: ""
        stdout: SplitParser {
            onRead: (line) => { sessionReadProc._buf += line + "\n" }
        }
        onRunningChanged: {
            if (running) return
            if (_buf.trim()) {
                try {
                    var data = JSON.parse(_buf.trim())
                    if (data.model) root.currentModel = data.model
                    if (data.messages) {
                        for (var i = 0; i < data.messages.length; i++)
                            root.messages.append(data.messages[i])
                        Qt.callLater(() => msgView.positionViewAtEnd())
                    }
                } catch(e) {}
            }
            _buf = ""
            root._sessionLoaded = true
            root._maybeAutoLoad()
        }
    }

    Process { id: sessionWriteProc }

    function saveSession() {
        if (streaming) return
        var data = { model: currentModel, messages: [] }
        for (var i = 0; i < messages.count; i++) {
            var m = messages.get(i)
            data.messages.push({ role: m.role, content: m.content, raw: m.raw || "" })
        }
        var json = JSON.stringify(data).replace(/'/g, "\\u0027")
        sessionWriteProc.running = false
        sessionWriteProc.command = ["sh", "-c",
            "mkdir -p ~/.local/share/quickshell && " +
            "printf '%s' '" + json + "' > " + _sessionPath
        ]
        sessionWriteProc.running = true
    }

    function deleteSession() {
        sessionWriteProc.running = false
        sessionWriteProc.command = ["sh", "-c", "rm -f " + _sessionPath]
        sessionWriteProc.running = true
    }

    // ── Clipboard ─────────────────────────────────────────────────────────
    Process {
        id: clipProc
    }

    function copyToClipboard(text) {
        clipProc.command = ["sh", "-c", "printf '%s' " + JSON.stringify(text) + " | wl-copy"]
        clipProc.running = false
        clipProc.running = true
    }

    // ── UI ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top bar — model selector + server control (matches TranslateView language bar)
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: Qt.rgba(0, 0, 0, 0.15)
            z: modelDropdown.visible ? 2 : 0

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 8

                Text {
                    text: "Model:"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                }

                // Model dropdown button
                Rectangle {
                    id: modelBtn
                    Layout.fillWidth: true
                    height: 26
                    radius: Theme.pillRadius
                    property bool locked: root.messages.count > 0
                    opacity: locked ? 0.5 : 1.0
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    color: modelBtnArea.containsMouse && !locked ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.04)
                    border.color: modelDropdown.visible ? Theme.notifBorderBase : Theme.notifBorderMid
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                        spacing: 4
                        Text {
                            text: "●"
                            font.pixelSize: 8
                            color: root.currentModel === LemonadeService.loadedModel ? Theme.green : Theme.fgDim
                            verticalAlignment: Text.AlignVCenter
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.currentModel !== "" ? root.currentModel
                                  : LemonadeService.serverRunning ? "No models" : "Server offline"
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            color: root.currentModel !== "" ? Theme.fg : Theme.fgDim
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: modelBtn.locked ? "lock" : modelDropdown.visible ? "expand_less" : "expand_more"
                            font.family:    Theme.iconFamily
                            font.pixelSize: 14
                            color: Theme.fgDim
                        }
                    }

                    MouseArea {
                        id: modelBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: modelBtn.locked ? Qt.ArrowCursor : Qt.PointingHandCursor
                        enabled: LemonadeService.models.count > 0 && !modelBtn.locked
                        onClicked: {
                            if (modelDropdown.visible) {
                                modelDropdown.visible = false
                            } else {
                                var p = modelBtn.mapToItem(root, 0, modelBtn.height + 2)
                                modelDropdown.x = p.x + 10
                                modelDropdown.y = p.y
                                modelDropdown.width = modelBtn.width
                                modelDropdown.visible = true
                            }
                        }
                    }
                }

                // Refresh button
                Text {
                    text: "refresh"
                    font.family:    Theme.iconFamily
                    font.pixelSize: 16
                    color: refreshHov.containsMouse ? Theme.accent : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    MouseArea {
                        id: refreshHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LemonadeService.refreshStatus()
                    }
                }

                // Server start / stop pill
                Rectangle {
                    height: 26
                    width: serverLabel.implicitWidth + 20
                    radius: Theme.pillRadius
                    color: {
                        if (LemonadeService.serverRunning)
                            return serverHov.containsMouse ? Qt.rgba(0.1, 0.5, 0.15, 0.4)
                                                          : Qt.rgba(0.08, 0.4, 0.12, 0.3)
                        return serverHov.containsMouse ? Qt.rgba(0.8, 0.2, 0.2, 0.5)
                                                      : Qt.rgba(0.7, 0.15, 0.15, 0.35)
                    }
                    border.color: LemonadeService.serverRunning
                                  ? Theme.green : Qt.rgba(1, 0.3, 0.3, 0.35)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        id: serverLabel
                        anchors.centerIn: parent
                        text: LemonadeService.starting ? "…"
                            : LemonadeService.stopping ? "…"
                            : LemonadeService.serverRunning ? "Stop" : "Start"
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fg
                    }

                    MouseArea {
                        id: serverHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !LemonadeService.starting && !LemonadeService.stopping
                        onClicked: LemonadeService.serverRunning
                                   ? LemonadeService.stopServer()
                                   : LemonadeService.startServer()
                    }
                }
            }
        }

        // Divider
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.notifBorderDim }

        // Messages
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ListView {
                id: msgView
                width: parent.width
                model: root.messages
                spacing: 8
                topMargin: 12
                bottomMargin: 12

                Text {
                    anchors.centerIn: parent
                    visible: root.messages.count === 0
                    text: LemonadeService.serverRunning
                          ? "Send a message to start chatting"
                          : "Start the Lemonade server to chat"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fgDim
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    width: parent.width - 40
                }

                delegate: Item {
                    id: msgDelegate
                    property bool isUser: model.role === "user"
                    property string msgContent: model.content || ""
                    property bool isLiveStream: root.streaming && !isUser &&
                                                index === root._chatAssistantIdx
                    property bool isInitialStream: isLiveStream && msgContent === ""
                    property var  segments: (!isUser && !isLiveStream)
                                            ? root.parseSegments(msgContent) : []

                    width: msgView.width - 20
                    height: bubbleRect.height

                    Rectangle {
                        id: bubbleRect
                        anchors.right:      isUser ? parent.right : undefined
                        anchors.left:       isUser ? undefined    : parent.left
                        anchors.leftMargin: isUser ? 0            : 6
                        width: isUser
                               ? Math.min(userText.implicitWidth + 20, parent.width * 0.88)
                               : parent.width
                        height: isUser       ? userText.contentHeight + 16
                              : isLiveStream ? streamText.contentHeight + 16
                              :                msgCol.implicitHeight + 16
                        radius: Theme.pillRadius
                        clip: true
                        color: isUser ? Qt.rgba(0.44, 0.39, 0.68, 0.35) : Theme.notifCardBg
                        border.color: isUser ? Qt.rgba(0.70, 0.62, 0.86, 0.25) : Theme.notifBorderDim
                        border.width: 1

                        // ── User bubble ───────────────────────────────────
                        TextEdit {
                            id: userText
                            visible: isUser
                            anchors { left: parent.left; right: parent.right
                                      leftMargin: 10; rightMargin: 10
                                      top: parent.top; topMargin: 8 }
                            text: isUser ? msgDelegate.msgContent : ""
                            textFormat: TextEdit.PlainText
                            readOnly: true
                            selectByMouse: true
                            selectedTextColor: Theme.bgSolid
                            selectionColor:    Theme.accent
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                            wrapMode: TextEdit.Wrap
                        }

                        // ── Live-stream bubble ────────────────────────────
                        TextEdit {
                            id: streamText
                            visible: isLiveStream
                            anchors { left: parent.left; right: parent.right
                                      leftMargin: 10; rightMargin: 10
                                      top: parent.top; topMargin: 8 }
                            text: isInitialStream ? "…" : msgDelegate.msgContent
                            textFormat: TextEdit.MarkdownText
                            readOnly: true
                            selectByMouse: true
                            selectedTextColor: Theme.bgSolid
                            selectionColor:    Theme.accent
                            font.family:    Theme.fontFamily
                            font.pixelSize: isInitialStream ? Theme.fontSize - 1 : Theme.fontSize
                            color: isInitialStream ? Theme.fgDim : Theme.fg
                            wrapMode: TextEdit.Wrap

                            SequentialAnimation on opacity {
                                running: isInitialStream
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600 }
                                NumberAnimation { to: 1.0; duration: 600 }
                            }
                        }

                        // ── Completed assistant bubble ────────────────────
                        Column {
                            id: msgCol
                            visible: !isUser && !isLiveStream
                            anchors { left: parent.left; right: parent.right
                                      leftMargin: 10; rightMargin: 10
                                      top: parent.top; topMargin: 8 }
                            spacing: 6

                            Repeater {
                                model: msgDelegate.segments

                                delegate: Item {
                                    id: segItem
                                    property var seg: modelData
                                    width: msgCol.width
                                    height: seg.type === "code"
                                            ? codeBox.height
                                            : segEdit.contentHeight

                                    TextEdit {
                                        id: segEdit
                                        visible: seg.type === "text"
                                        width: parent.width
                                        height: contentHeight
                                        text: seg.type === "text" ? seg.content : ""
                                        textFormat: TextEdit.MarkdownText
                                        readOnly: true
                                        selectByMouse: true
                                        font.family:    Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        color: Theme.fg
                                        wrapMode: TextEdit.Wrap
                                        selectedTextColor: Theme.bgSolid
                                        selectionColor:    Theme.accent
                                    }

                                    Rectangle {
                                        id: codeBox
                                        visible: seg.type === "code"
                                        width: parent.width
                                        height: codeEdit.contentHeight + 32
                                        radius: 4
                                        color: Qt.rgba(0, 0, 0, 0.35)
                                        border.color: Theme.notifBorderMid
                                        border.width: 1
                                        clip: true

                                        TextEdit {
                                            id: codeEdit
                                            anchors { left: parent.left; right: parent.right
                                                      leftMargin: 8; rightMargin: 8
                                                      top: parent.top; topMargin: 16 }
                                            height: contentHeight
                                            text: seg.type === "code" ? seg.content : ""
                                            textFormat: TextEdit.PlainText
                                            readOnly: true
                                            selectByMouse: true
                                            font.family:    Theme.monoFamily
                                            font.pixelSize: Theme.fontSize - 1
                                            color: Theme.fg
                                            wrapMode: TextEdit.WrapAnywhere
                                            selectedTextColor: Theme.bgSolid
                                            selectionColor:    Theme.accent
                                        }

                                        Rectangle {
                                            anchors { right: parent.right; top: parent.top; margins: 4 }
                                            width: 20; height: 20
                                            radius: 4
                                            color: codeHov.containsMouse ? Theme.bgHover : "transparent"
                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                            Text {
                                                id: copyIcon
                                                property bool copied: false
                                                anchors.centerIn: parent
                                                text: copied ? "check" : "content_copy"
                                                font.family:    Theme.iconFamily
                                                font.pixelSize: 12
                                                color: copied ? Theme.green
                                                              : codeHov.containsMouse ? Theme.accent : Theme.fgDim
                                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                                Timer {
                                                    id: copyResetTimer
                                                    interval: 1500
                                                    onTriggered: copyIcon.copied = false
                                                }
                                            }

                                            MouseArea {
                                                id: codeHov
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.copyToClipboard(seg.content)
                                                    copyIcon.copied = true
                                                    copyResetTimer.restart()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Divider
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.notifBorderDim }

        // File attachment bar (visible when file attached or file input shown)
        Rectangle {
            Layout.fillWidth: true
            height: visible ? 36 : 0
            visible: showFileInput || attachedFilePath !== ""
            color: Qt.rgba(0, 0, 0, 0.1)

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 8

                Text {
                    text: "attach_file"
                    font.family:    Theme.iconFamily
                    font.pixelSize: 14
                    color: Theme.fgDim
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 24
                    radius: Theme.pillRadius
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: filePathInput.activeFocus ? Theme.notifBorderBase : Theme.notifBorderDim
                    border.width: 1
                    visible: showFileInput && attachedFilePath === ""

                    TextField {
                        id: filePathInput
                        anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                        placeholderText: "File path…"
                        placeholderTextColor: Theme.fgDim
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fg
                        background: null
                        padding: 4
                        onAccepted: {
                            var p = text.trim()
                            if (p) {
                                root.attachedFilePath = p
                                root.readFileAsBase64(p)
                                text = ""
                            }
                        }
                    }
                }

                Rectangle {
                    visible: attachedFilePath !== ""
                    Layout.fillWidth: true
                    height: 24
                    radius: Theme.pillRadius
                    color: Qt.rgba(0.44, 0.39, 0.68, 0.2)
                    border.color: Qt.rgba(0.70, 0.62, 0.86, 0.2)
                    border.width: 1

                    Text {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        text: attachedFilePath.split("/").pop()
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fg
                        elide: Text.ElideLeft
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    text: "close"
                    font.family:    Theme.iconFamily
                    font.pixelSize: 14
                    color: clearFileHov.containsMouse ? Theme.red : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    MouseArea {
                        id: clearFileHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.attachedFilePath   = ""
                            root.attachedFileBase64 = ""
                            root.showFileInput      = false
                            filePathInput.text      = ""
                        }
                    }
                }
            }
        }

        // Input row
        Rectangle {
            id: inputRowBar
            Layout.fillWidth: true
            property real pillHeight: Math.min(Math.max(inputArea.contentHeight + 14, 36), 220)
            Layout.preferredHeight: pillHeight + 14
            color: "transparent"

            RowLayout {
                anchors { left: parent.left; right: parent.right;
                          verticalCenter: parent.verticalCenter; margins: 10 }
                spacing: 8

                // File attach button (only for vision models)
                Rectangle {
                    width: 32; height: 32
                    radius: Theme.pillRadius
                    visible: LemonadeService.isVisionModel(root.currentModel)
                    color: fileAttHov.containsMouse || root.showFileInput
                           ? Theme.bgHover : "transparent"
                    border.color: root.showFileInput ? Theme.notifBorderBase : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "attach_file"
                        font.family:    Theme.iconFamily
                        font.pixelSize: 16
                        color: fileAttHov.containsMouse ? Theme.accent : Theme.fgDim
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    MouseArea {
                        id: fileAttHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showFileInput = !root.showFileInput
                            if (root.showFileInput) filePathInput.forceActiveFocus()
                        }
                    }
                }

                // Text input
                Rectangle {
                    id: inputPill
                    Layout.fillWidth: true
                    Layout.preferredHeight: inputRowBar.pillHeight
                    radius: Theme.pillRadius
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: inputArea.activeFocus ? Theme.notifBorderBase : Theme.notifBorderDim
                    border.width: 1

                    Flickable {
                        id: inputFlick
                        anchors { fill: parent; topMargin: 7; bottomMargin: 7; leftMargin: 10; rightMargin: 10 }
                        contentWidth: width
                        contentHeight: inputArea.contentHeight
                        clip: true
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                        TextArea {
                            id: inputArea
                            width: inputFlick.width
                            placeholderText: LemonadeService.serverRunning
                                             ? "Message…" : "Server offline"
                            placeholderTextColor: Theme.fgDim
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                            wrapMode: TextArea.Wrap
                            background: null
                            padding: 0
                            enabled: LemonadeService.serverRunning && !root.streaming

                            Keys.onReturnPressed: (event) => {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    event.accepted = false
                                } else {
                                    event.accepted = true
                                    root.sendMessage()
                                }
                            }
                        }
                    }
                }

                // Send / Stop button
                Rectangle {
                    width: 36; height: 36
                    radius: Theme.pillRadius
                    property bool canSend: LemonadeService.serverRunning && !root.streaming
                    color: root.streaming        ? Qt.rgba(0.44, 0.39, 0.68, 0.2)
                         : !canSend             ? Qt.rgba(0.44, 0.39, 0.68, 0.15)
                         : sendBtnHov.containsMouse ? Theme.accentDim : Theme.accent
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: root.streaming ? "stop" : "send"
                        font.family:    Theme.iconFamily
                        font.pixelSize: 18
                        color: (root.streaming || !LemonadeService.serverRunning) ? Theme.fgDim : Theme.bgSolid
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    MouseArea {
                        id: sendBtnHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: LemonadeService.serverRunning ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: LemonadeService.serverRunning
                        onClicked: {
                            if (root.streaming) chatProc.running = false
                            else root.sendMessage()
                        }
                    }
                }

                // Clear button
                Rectangle {
                    width: 36; height: 36
                    radius: Theme.pillRadius
                    color: clearHov.containsMouse ? Theme.bgHover : "transparent"
                    border.color: Theme.notifBorderMid
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "delete_sweep"
                        font.family:    Theme.iconFamily
                        font.pixelSize: 18
                        color: clearHov.containsMouse ? Theme.red : Theme.fgDim
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    MouseArea {
                        id: clearHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.messages.clear()
                            root.deleteSession()
                        }
                    }
                }
            }
        }
    }

    // ── Model dropdown overlay ────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: modelDropdown.visible
        z: 9
        onClicked: modelDropdown.visible = false
    }

    Rectangle {
        id: modelDropdown
        visible: false
        z: 10
        radius: Theme.pillRadius
        color: Theme.bgSolid
        border.color: Theme.notifBorderBase
        border.width: 1
        clip: true
        height: Math.min(modelDropList.contentHeight + 8, 220)

        ListView {
            id: modelDropList
            anchors { fill: parent; margins: 4 }
            model: LemonadeService.models
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: Rectangle {
                width: modelDropList.width
                height: 28
                color: mItemHov.containsMouse ? Theme.notifHoverBg : "transparent"
                radius: 4
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                    spacing: 6
                    Text {
                        text: "●"
                        font.pixelSize: 8
                        color: (model.name || "") === LemonadeService.loadedModel ? Theme.green : Theme.fgDim
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: model.name || ""
                        color: root.currentModel === (model.name || "") ? Theme.accent : Theme.fg
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    id: mItemHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentModel = model.name || ""
                        modelDropdown.visible = false
                    }
                }
            }
        }
    }
}
