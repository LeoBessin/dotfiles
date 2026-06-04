import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import ".."

Item {
    id: root

    // ── Conversation data ─────────────────────────────────────────────────
    property var conversations: []      // [{id, title, model, messages:[]}]
    property int currentConvIndex: -1
    property bool streaming: false
    property string currentModel: ""
    property string attachedFilePath: ""
    property string attachedFileBase64: ""
    property bool showFileInput: false
    property int deleteConfirmIndex: -1  // which conv pill shows delete confirm

    property ListModel messages: ListModel {}

    // ── Lifecycle ─────────────────────────────────────────────────────────
    Component.onCompleted: {
        LemonadeService.refreshStatus()
        newConversation()
    }

    onCurrentModelChanged: {
        if (currentConvIndex >= 0 && conversations[currentConvIndex])
            conversations[currentConvIndex].model = currentModel
    }

    // ── Conversation management ───────────────────────────────────────────
    function newConversation() {
        _saveCurrentConv()
        var defaultModel = LemonadeService.models.count > 0
                           ? LemonadeService.models.get(0).name : ""
        var conv = { id: "conv_" + Date.now(), title: "New conversation",
                     model: defaultModel, messages: [] }
        conversations.push(conv)
        conversations = conversations
        currentConvIndex = conversations.length - 1
        messages.clear()
        currentModel = defaultModel
        deleteConfirmIndex = -1
    }

    function switchConv(index) {
        if (index === currentConvIndex) return
        _saveCurrentConv()
        _loadConv(index)
        deleteConfirmIndex = -1
    }

    function deleteConv(index) {
        deleteConfirmIndex = -1
        if (conversations.length <= 1) {
            // Just clear the single conversation
            messages.clear()
            conversations[0].title    = "New conversation"
            conversations[0].messages = []
            conversations = conversations
            return
        }
        conversations.splice(index, 1)
        conversations = conversations
        var newIdx = Math.min(currentConvIndex, conversations.length - 1)
        currentConvIndex = -1   // force reload
        _loadConv(newIdx)
    }

    function _saveCurrentConv() {
        if (currentConvIndex < 0 || !conversations[currentConvIndex]) return
        var msgs = []
        for (var i = 0; i < messages.count; i++) {
            var m = messages.get(i)
            msgs.push({ role: m.role, content: m.content, raw: m.raw || m.content })
        }
        conversations[currentConvIndex].messages = msgs
        conversations[currentConvIndex].model    = currentModel
    }

    function _loadConv(index) {
        currentConvIndex = index
        var conv = conversations[index]
        currentModel = conv.model ||
                       (LemonadeService.models.count > 0 ? LemonadeService.models.get(0).name : "")
        messages.clear()
        for (var i = 0; i < conv.messages.length; i++)
            messages.append(conv.messages[i])
        Qt.callLater(() => msgView.positionViewAtEnd())
    }

    function _updateConvTitle() {
        var conv = conversations[currentConvIndex]
        if (!conv || conv.title !== "New conversation") return
        for (var i = 0; i < messages.count; i++) {
            if (messages.get(i).role === "user") {
                var t = messages.get(i).content
                conv.title = t.length > 28 ? t.substring(0, 28) + "…" : t
                conversations = conversations
                break
            }
        }
    }

    // ── Send message ──────────────────────────────────────────────────────
    function sendMessage() {
        var input = inputArea.text.trim()
        if (!input || streaming || currentConvIndex < 0) return
        if (!LemonadeService.serverRunning) return

        // Build user content (plain or vision array)
        var hasFile = attachedFilePath && attachedFileBase64 &&
                      LemonadeService.isVisionModel(currentModel)
        var userContent = hasFile
            ? JSON.stringify([
                { type: "text", text: input },
                { type: "image_url", image_url: { url: "data:image/jpeg;base64," + attachedFileBase64 } }
              ])
            : input

        // Collect API messages from current conversation history
        var apiMessages = []
        for (var i = 0; i < messages.count; i++) {
            var m = messages.get(i)
            var raw = m.raw || m.content
            var parsed = raw
            try { parsed = JSON.parse(raw) } catch(e) {}
            apiMessages.push({ role: m.role, content: parsed })
        }
        // Add new user message
        apiMessages.push({ role: "user", content: hasFile ? JSON.parse(userContent) : input })

        // Append to display
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
        _updateConvTitle()
        Qt.callLater(() => msgView.positionViewAtEnd())

        // Encode single quotes as ' so the JSON is safe inside a single-quoted shell arg
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
            root._saveCurrentConv()
            root._chatAssistantIdx = -1
            Qt.callLater(() => msgView.positionViewAtEnd())
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

    // ── UI ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Server status banner
        Rectangle {
            Layout.fillWidth: true
            height: visible ? 36 : 0
            visible: LemonadeService.statusChecked && !LemonadeService.serverRunning
            color: Qt.rgba(0.6, 0.1, 0.1, 0.3)

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 8

                Text {
                    text: "circle"
                    font.family:    Theme.iconFamily
                    font.pixelSize: 12
                    color: Theme.red
                }

                Text {
                    Layout.fillWidth: true
                    text: "Lemonade server offline"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fg
                }

                Rectangle {
                    width: 52; height: 22
                    radius: Theme.pillRadius
                    color: startHov.containsMouse ? Qt.rgba(0.8,0.2,0.2,0.5) : Qt.rgba(0.7,0.15,0.15,0.35)
                    border.color: Qt.rgba(1,0.3,0.3,0.35)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: LemonadeService.starting ? "…" : "Start"
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fg
                    }

                    MouseArea {
                        id: startHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !LemonadeService.starting
                        onClicked: LemonadeService.startServer()
                    }
                }
            }
        }

        // Server running banner
        Rectangle {
            Layout.fillWidth: true
            height: visible ? 36 : 0
            visible: LemonadeService.serverRunning
            color: Qt.rgba(0.1, 0.5, 0.1, 0.3)

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 8

                Text {
                    text: "circle"
                    font.family:    Theme.iconFamily
                    font.pixelSize: 12
                    color: Theme.green
                }

                Text {
                    Layout.fillWidth: true
                    text: "Lemonade server running"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fg
                }

                Rectangle {
                    width: 52; height: 22
                    radius: Theme.pillRadius
                    color: stopHov.containsMouse ? Qt.rgba(0.1,0.5,0.15,0.4) : Qt.rgba(0.08,0.4,0.12,0.3)
                    border.color: Theme.green
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: LemonadeService.stopping ? "…" : "Stop"
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fg
                    }

                    MouseArea {
                        id: stopHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !LemonadeService.stopping
                        onClicked: LemonadeService.stopServer()
                    }
                }
            }
        }

        // Conversation list
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: Qt.rgba(0, 0, 0, 0.1)

            RowLayout {
                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                spacing: 4

                // New conversation button
                Rectangle {
                    width: 28; height: 28
                    radius: Theme.pillRadius
                    color: newConvHov.containsMouse ? Theme.bgHover : "transparent"
                    border.color: Theme.notifBorderMid
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "add"
                        font.family:    Theme.iconFamily
                        font.pixelSize: 16
                        color: newConvHov.containsMouse ? Theme.accent : Theme.fgDim
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    MouseArea {
                        id: newConvHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.newConversation()
                    }
                }

                // Conversation pills (horizontal scroll)
                ListView {
                    id: convList
                    Layout.fillWidth: true
                    height: 28
                    orientation: ListView.Horizontal
                    spacing: 4
                    clip: true
                    model: root.conversations
                    currentIndex: root.currentConvIndex

                    delegate: Item {
                        id: convDelegate
                        property int convIdx: index
                        property bool isActive: index === root.currentConvIndex
                        property bool showConfirm: index === root.deleteConfirmIndex

                        height: 28
                        width: showConfirm ? confirmRow.implicitWidth + 16
                                           : Math.min(pillLabel.implicitWidth + 36, 140)

                        Behavior on width { NumberAnimation { duration: Theme.animFast } }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.pillRadius
                            color: isActive ? Qt.rgba(0.44, 0.39, 0.68, 0.35)
                                            : pillHov.containsMouse ? Theme.bgHover : Qt.rgba(1,1,1,0.04)
                            border.color: isActive ? Qt.rgba(0.70, 0.62, 0.86, 0.35) : Theme.notifBorderDim
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            // Normal pill content
                            RowLayout {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                spacing: 4
                                visible: !showConfirm

                                Text {
                                    id: pillLabel
                                    Layout.fillWidth: true
                                    text: modelData ? modelData.title : ""
                                    font.family:    Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    color: isActive ? Theme.fg : Theme.fgDim
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "close"
                                    font.family:    Theme.iconFamily
                                    font.pixelSize: 12
                                    color: delHov.containsMouse ? Theme.red : Theme.fgDim
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    MouseArea {
                                        id: delHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.deleteConfirmIndex = convIdx
                                    }
                                }
                            }

                            // Delete confirmation
                            RowLayout {
                                id: confirmRow
                                anchors.centerIn: parent
                                spacing: 4
                                visible: showConfirm

                                Text {
                                    text: "Delete?"
                                    font.family:    Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                    color: Theme.fgDim
                                }

                                Rectangle {
                                    width: 30; height: 18
                                    radius: 4
                                    color: yesHov.containsMouse ? Qt.rgba(0.8,0.2,0.2,0.6) : Qt.rgba(0.6,0.1,0.1,0.4)
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Yes"
                                        font.family:    Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 2
                                        color: Theme.fg
                                    }
                                    MouseArea {
                                        id: yesHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.deleteConv(convIdx)
                                    }
                                }

                                Rectangle {
                                    width: 26; height: 18
                                    radius: 4
                                    color: noHov.containsMouse ? Theme.bgHover : Qt.rgba(1,1,1,0.06)
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "No"
                                        font.family:    Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 2
                                        color: Theme.fgDim
                                    }
                                    MouseArea {
                                        id: noHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.deleteConfirmIndex = -1
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: pillHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !showConfirm
                            onClicked: root.switchConv(convIdx)
                        }
                    }
                }
            }
        }

        // Divider
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.notifBorderDim }

        // Model selector row
        Rectangle {
            id: modelRow
            Layout.fillWidth: true
            height: 38
            color: Qt.rgba(0, 0, 0, 0.08)
            z: modelDropdown.visible ? 2 : 0

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 8

                Text {
                    text: "Model:"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                }

                // Custom inline dropdown button
                Rectangle {
                    id: modelBtn
                    Layout.fillWidth: true
                    height: 26
                    radius: Theme.pillRadius
                    color: modelBtnArea.containsMouse ? Theme.bgHover : Qt.rgba(1,1,1,0.04)
                    border.color: modelDropdown.visible ? Theme.notifBorderBase : Theme.notifBorderMid
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                        spacing: 4
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
                            text: modelDropdown.visible ? "expand_less" : "expand_more"
                            font.family:    Theme.iconFamily
                            font.pixelSize: 14
                            color: Theme.fgDim
                        }
                    }

                    MouseArea {
                        id: modelBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: LemonadeService.models.count > 0
                        onClicked: {
                            if (modelDropdown.visible) {
                                modelDropdown.visible = false
                            } else {
                                var p = modelBtn.mapToItem(root, 0, modelBtn.height + 2)
                                modelDropdown.x = p.x + 12
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

                // Empty state
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
                    property bool isStreaming: model.role === "assistant" &&
                                               model.content === "" &&
                                               root.streaming

                    width: msgView.width - 20
                    height: bubbleRect.height

                    Rectangle {
                        id: bubbleRect
                        anchors.right:      isUser ? parent.right : undefined
                        anchors.left:       isUser ? undefined    : parent.left
                        anchors.leftMargin: isUser ? 0            : 6
                        width: Math.min(msgText.implicitWidth + 20, parent.width * 0.88)
                        height: msgText.implicitHeight + 16
                        radius: Theme.pillRadius
                        color: isUser
                               ? Qt.rgba(0.44, 0.39, 0.68, 0.35)
                               : Theme.notifCardBg
                        border.color: isUser
                                      ? Qt.rgba(0.70, 0.62, 0.86, 0.25)
                                      : Theme.notifBorderDim
                        border.width: 1

                        Text {
                            id: msgText
                            anchors {
                                left: parent.left; right: parent.right
                                leftMargin: 10; rightMargin: 10
                                top:              isUser ? parent.top          : undefined
                                verticalCenter:   isUser ? undefined           : parent.verticalCenter
                                topMargin:        isUser ? 8                   : 0
                            }
                            text: isStreaming ? "…" : (model.content || "")
                            textFormat: isUser ? Text.PlainText : Text.MarkdownText
                            font.family:    Theme.fontFamily
                            font.pixelSize: isStreaming ? Theme.fontSize - 1 : Theme.fontSize
                            color: isStreaming ? Theme.fgDim : Theme.fg
                            wrapMode: Text.Wrap
                            linkColor: Theme.accent

                            SequentialAnimation on opacity {
                                running: isStreaming
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600 }
                                NumberAnimation { to: 1.0; duration: 600 }
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

                // File path input
                Rectangle {
                    Layout.fillWidth: true
                    height: 24
                    radius: Theme.pillRadius
                    color: Qt.rgba(1,1,1,0.04)
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

                // Attached filename pill
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

                // Clear attachment
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
            Layout.fillWidth: true
            height: inputRowLayout.implicitHeight + 14
            color: "transparent"

            RowLayout {
                id: inputRowLayout
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
                    Layout.fillWidth: true
                    height: Math.min(Math.max(inputArea.implicitHeight + 14, 36), 120)
                    radius: Theme.pillRadius
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: inputArea.activeFocus ? Theme.notifBorderBase : Theme.notifBorderDim
                    border.width: 1

                    TextArea {
                        id: inputArea
                        anchors { left: parent.left; right: parent.right;
                                  verticalCenter: parent.verticalCenter; margins: 10 }
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

                // Send button
                Rectangle {
                    width: 36; height: 36
                    radius: Theme.pillRadius
                    color: root.streaming
                           ? Qt.rgba(0.44, 0.39, 0.68, 0.2)
                           : sendBtnHov.containsMouse ? Theme.accentDim : Theme.accent
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: root.streaming ? "stop" : "send"
                        font.family:    Theme.iconFamily
                        font.pixelSize: 18
                        color: root.streaming ? Theme.fgDim : Theme.bgSolid
                    }

                    MouseArea {
                        id: sendBtnHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: LemonadeService.serverRunning
                        onClicked: {
                            if (root.streaming) chatProc.running = false
                            else root.sendMessage()
                        }
                    }
                }
            }
        }
    }

    // ── Model dropdown overlay ────────────────────────────────────────────
    // Backdrop: closes dropdown when clicking outside
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
                Text {
                    anchors { fill: parent; leftMargin: 10 }
                    text: model.name || ""
                    color: root.currentModel === (model.name || "") ? Theme.accent : Theme.fg
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
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
