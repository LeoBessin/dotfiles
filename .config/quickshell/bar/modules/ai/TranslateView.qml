import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import ".."

Item {
    id: root

    // ── Language data ─────────────────────────────────────────────────────
    property bool langsLoaded: false

    // srcLangModel: includes Auto-detect (source selector)
    ListModel {
        id: srcLangModel
        ListElement { code: "auto"; label: "Auto-detect" }
    }
    // tgtLangModel: real languages only (target selector)
    ListModel {
        id: tgtLangModel
    }

    // ── Translation history ───────────────────────────────────────────────
    property ListModel history: ListModel {}
    property bool translating: false

    property string sourceLang: "auto"
    property string targetLang: "en"
    property int srcCurrentIndex: 0
    property int tgtCurrentIndex: 0

    // Load language list once
    function loadLanguages() {
        if (langsLoaded) return
        langLoaderProc.running = false
        langLoaderProc.running = true
    }

    // Jump the dropdown highlight to the first/next language whose label
    // starts with the typed letter (cycles through matches on repeat press).
    function _jumpToLetter(listView, model, ch) {
        var lower = ch.toLowerCase()
        var count = model.count
        if (count === 0) return
        var start = (listView.currentIndex + 1 + count) % count
        for (var i = 0; i < count; i++) {
            var idx = (start + i) % count
            var label = model.get(idx).label
            if (label && label.charAt(0).toLowerCase() === lower) {
                listView.currentIndex = idx
                listView.positionViewAtIndex(idx, ListView.Contain)
                return
            }
        }
    }

    function doTranslate() {
        var input = inputArea.text.trim()
        if (!input || translating) return

        history.append({
            inputText:  input,
            outputText: "…",
            src: sourceLang,
            tgt: targetLang
        })
        var idx = history.count - 1
        inputArea.text = ""
        translating = true

        var src = sourceLang === "auto" ? "" : sourceLang
        var langArg = src + ":" + targetLang
        transProc.command = ["trans", "-b", "-no-ansi", langArg, input]
        transProc._targetIdx = idx
        transProc.running = false
        transProc.running = true
        Qt.callLater(() => histView.positionViewAtEnd())
    }

    // ── Language loader ───────────────────────────────────────────────────
    Process {
        id: langLoaderProc
        command: ["trans", "-list-all"]
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim()
                if (!trimmed) return
                var parts = trimmed.split(/\s{2,}/)
                if (parts.length < 2) return
                var code = parts[0].trim()
                var name = parts[1].trim()
                if (!code || !name) return
                var entry = { code: code, label: name + " (" + code + ")" }
                srcLangModel.append(entry)
                tgtLangModel.append(entry)
            }
        }
        onRunningChanged: {
            if (!running) {
                root.langsLoaded = true
                for (var i = 0; i < tgtLangModel.count; i++) {
                    if (tgtLangModel.get(i).code === "en") {
                        root.tgtCurrentIndex = i
                        root.targetLang = "en"
                        break
                    }
                }
            }
        }
    }

    // ── Translator process ────────────────────────────────────────────────
    Process {
        id: transProc
        property int _targetIdx: -1
        property string _buffer: ""

        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim()) transProc._buffer += (transProc._buffer ? "\n" : "") + line.trim()
            }
        }

        onRunningChanged: {
            if (!running) {
                if (_targetIdx >= 0 && _targetIdx < root.history.count) {
                    root.history.setProperty(_targetIdx, "outputText",
                        _buffer || "(no translation)")
                }
                _buffer = ""
                root.translating = false
                Qt.callLater(() => histView.positionViewAtEnd())
            }
        }
    }

    // ── Copy helper ───────────────────────────────────────────────────────
    Process {
        id: copyProc
        command: ["wl-copy", ""]
    }

    // ── UI ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Language selector bar
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: Qt.rgba(0, 0, 0, 0.15)
            z: (srcDropdown.visible || tgtDropdown.visible) ? 2 : 0

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "From:"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fgDim
                }

                // Source language button
                Rectangle {
                    id: srcBtn
                    Layout.preferredWidth: 140
                    height: 26
                    radius: Theme.pillRadius
                    color: srcBtnArea.containsMouse ? Theme.bgHover : Qt.rgba(1,1,1,0.04)
                    border.color: srcDropdown.visible ? Theme.notifBorderBase : Theme.notifBorderMid
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: srcLangModel.count > 0 ? srcLangModel.get(srcCurrentIndex).label : "Auto-detect"
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            color: Theme.fg
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: srcDropdown.visible ? "expand_less" : "expand_more"
                            font.family:    Theme.iconFamily
                            font.pixelSize: 13
                            color: Theme.fgDim
                        }
                    }
                    MouseArea {
                        id: srcBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            tgtDropdown.visible = false
                            if (srcDropdown.visible) { srcDropdown.visible = false; return }
                            var p = srcBtn.mapToItem(root, 0, srcBtn.height + 2)
                            srcDropdown.x = p.x
                            srcDropdown.y = p.y
                            srcDropdown.visible = true
                        }
                    }
                }

                Text {
                    text: "To:"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fgDim
                }

                // Target language button
                Rectangle {
                    id: tgtBtn
                    Layout.preferredWidth: 140
                    height: 26
                    radius: Theme.pillRadius
                    color: tgtBtnArea.containsMouse ? Theme.bgHover : Qt.rgba(1,1,1,0.04)
                    border.color: tgtDropdown.visible ? Theme.notifBorderBase : Theme.notifBorderMid
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: tgtLangModel.count > 0 && tgtCurrentIndex >= 0
                                  ? tgtLangModel.get(tgtCurrentIndex).label : "Select…"
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            color: Theme.fg
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: tgtDropdown.visible ? "expand_less" : "expand_more"
                            font.family:    Theme.iconFamily
                            font.pixelSize: 13
                            color: Theme.fgDim
                        }
                    }
                    MouseArea {
                        id: tgtBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            srcDropdown.visible = false
                            if (tgtDropdown.visible) { tgtDropdown.visible = false; return }
                            var p = tgtBtn.mapToItem(root, 0, tgtBtn.height + 2)
                            tgtDropdown.x = p.x
                            tgtDropdown.y = p.y
                            tgtDropdown.visible = true
                        }
                    }
                }
            }
        }

        // Divider
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.notifBorderDim }

        // History
        ScrollView {
            id: histScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ListView {
                id: histView
                width: parent.width
                model: root.history
                spacing: 6
                topMargin: 10
                bottomMargin: 10

                delegate: Item {
                    width: histView.width - 20
                    height: pairCol.implicitHeight

                    Column {
                        id: pairCol
                        width: parent.width
                        spacing: 4

                        // User input bubble (right)
                        Item {
                            width: parent.width
                            height: userBubble.height

                            Rectangle {
                                id: userBubble
                                anchors.right: parent.right
                                width: Math.min(userText.implicitWidth + 20, parent.width * 0.85)
                                height: userText.contentHeight + 16
                                radius: Theme.pillRadius
                                color: Qt.rgba(0.44, 0.39, 0.68, 0.35)
                                border.color: Qt.rgba(0.70, 0.62, 0.86, 0.25)
                                border.width: 1

                                TextEdit {
                                    id: userText
                                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 10; rightMargin: 10; topMargin: 8 }
                                    text: model.inputText
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
                            }
                        }

                        // Translation bubble (left)
                        Item {
                            width: parent.width
                            height: transBubble.height

                            Rectangle {
                                id: transBubble
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                width: Math.min(transText.implicitWidth + (model.outputText !== "…" ? 40 : 20), parent.width * 0.85)
                                height: transText.contentHeight + 16
                                radius: Theme.pillRadius
                                color: Theme.notifCardBg
                                border.color: Theme.notifBorderDim
                                border.width: 1

                                TextEdit {
                                    id: transText
                                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 10; rightMargin: model.outputText !== "…" ? 30 : 10; topMargin: 8 }
                                    text: model.outputText
                                    textFormat: TextEdit.PlainText
                                    readOnly: true
                                    selectByMouse: true
                                    selectedTextColor: Theme.bgSolid
                                    selectionColor:    Theme.accent
                                    font.family:    Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    color: model.outputText === "…" ? Theme.fgDim : Theme.fg
                                    wrapMode: TextEdit.Wrap
                                }

                                Text {
                                    id: copyBtn
                                    property bool copied: false
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 }
                                    text: copied ? "check" : "content_copy"
                                    font.family:    Theme.iconFamily
                                    font.pixelSize: 16
                                    color: copied ? Theme.green : (copyHov.containsMouse ? Theme.accent : Theme.fgDim)
                                    visible: model.outputText !== "…"
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    MouseArea {
                                        id: copyHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            copyProc.command = ["wl-copy", model.outputText]
                                            copyProc.running = false
                                            copyProc.running = true
                                            copyBtn.copied = true
                                            copyTimer.restart()
                                        }
                                    }

                                    Timer {
                                        id: copyTimer
                                        interval: 1500
                                        onTriggered: copyBtn.copied = false
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

        // Input row
        Rectangle {
            id: inputRowBar
            Layout.fillWidth: true
            // Grow with content up to a cap, then the Flickable scrolls.
            // Derived from contentHeight (not inputPill.height) to avoid a binding loop.
            property real pillHeight: Math.min(Math.max(inputArea.contentHeight + 14, 36), 200)
            Layout.preferredHeight: pillHeight + 16
            color: "transparent"

            RowLayout {
                id: inputRow
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                spacing: 8

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
                            placeholderText: "Enter text to translate…"
                            placeholderTextColor: Theme.fgDim
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                            wrapMode: TextArea.Wrap
                            background: null
                            padding: 0

                            Keys.onReturnPressed: (event) => {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    event.accepted = false
                                } else {
                                    event.accepted = true
                                    root.doTranslate()
                                }
                            }
                        }
                    }
                }

                // Translate button
                Rectangle {
                    width: 36; height: 36
                    radius: Theme.pillRadius
                    color: sendHov.containsMouse ? Theme.accentDim : Theme.accent
                    opacity: root.translating ? 0.5 : 1.0
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: root.translating ? "hourglass_empty" : "translate"
                        font.family:    Theme.iconFamily
                        font.pixelSize: 18
                        color: Theme.bgSolid
                    }

                    MouseArea {
                        id: sendHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.translating
                        onClicked: root.doTranslate()
                    }
                }

                // Clear all button
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
                        onClicked: root.history.clear()
                    }
                }
            }
        }
    }

    Component.onCompleted: loadLanguages()

    // ── Language dropdown overlays ─────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: srcDropdown.visible || tgtDropdown.visible
        z: 9
        onClicked: { srcDropdown.visible = false; tgtDropdown.visible = false }
    }

    Rectangle {
        id: srcDropdown
        visible: false
        z: 10
        width: 160
        height: Math.min(srcDropList.contentHeight + 8, 260)
        radius: Theme.pillRadius
        color: Theme.bgSolid
        border.color: Theme.notifBorderBase
        border.width: 1
        clip: true

        onVisibleChanged: {
            if (visible) {
                srcDropList.currentIndex = root.srcCurrentIndex
                srcDropList.positionViewAtIndex(root.srcCurrentIndex, ListView.Contain)
                srcDropList.forceActiveFocus()
            }
        }

        ListView {
            id: srcDropList
            anchors { fill: parent; margins: 4 }
            model: srcLangModel
            keyNavigationEnabled: true
            highlightMoveDuration: 0
            currentIndex: -1
            highlight: Rectangle { color: Theme.notifHoverBg; radius: 4 }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (currentIndex >= 0) {
                        root.srcCurrentIndex = currentIndex
                        root.sourceLang = srcLangModel.get(currentIndex).code
                    }
                    srcDropdown.visible = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    srcDropdown.visible = false
                    event.accepted = true
                } else if (event.text.length === 1 && /[a-zA-Z]/.test(event.text)) {
                    root._jumpToLetter(srcDropList, srcLangModel, event.text)
                    event.accepted = true
                }
            }

            delegate: Rectangle {
                width: srcDropList.width
                height: 26
                color: sItemHov.containsMouse ? Theme.notifHoverBg : "transparent"
                radius: 4
                Text {
                    anchors { fill: parent; leftMargin: 8 }
                    text: model.label
                    color: root.srcCurrentIndex === index ? Theme.accent : Theme.fg
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: sItemHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.srcCurrentIndex = index
                        root.sourceLang = srcLangModel.get(index).code
                        srcDropdown.visible = false
                    }
                }
            }
        }
    }

    Rectangle {
        id: tgtDropdown
        visible: false
        z: 10
        width: 160
        height: Math.min(tgtDropList.contentHeight + 8, 260)
        radius: Theme.pillRadius
        color: Theme.bgSolid
        border.color: Theme.notifBorderBase
        border.width: 1
        clip: true

        onVisibleChanged: {
            if (visible) {
                tgtDropList.currentIndex = root.tgtCurrentIndex
                tgtDropList.positionViewAtIndex(root.tgtCurrentIndex, ListView.Contain)
                tgtDropList.forceActiveFocus()
            }
        }

        ListView {
            id: tgtDropList
            anchors { fill: parent; margins: 4 }
            model: tgtLangModel
            keyNavigationEnabled: true
            highlightMoveDuration: 0
            currentIndex: -1
            highlight: Rectangle { color: Theme.notifHoverBg; radius: 4 }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (currentIndex >= 0) {
                        root.tgtCurrentIndex = currentIndex
                        root.targetLang = tgtLangModel.get(currentIndex).code
                    }
                    tgtDropdown.visible = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    tgtDropdown.visible = false
                    event.accepted = true
                } else if (event.text.length === 1 && /[a-zA-Z]/.test(event.text)) {
                    root._jumpToLetter(tgtDropList, tgtLangModel, event.text)
                    event.accepted = true
                }
            }

            delegate: Rectangle {
                width: tgtDropList.width
                height: 26
                color: tItemHov.containsMouse ? Theme.notifHoverBg : "transparent"
                radius: 4
                Text {
                    anchors { fill: parent; leftMargin: 8 }
                    text: model.label
                    color: root.tgtCurrentIndex === index ? Theme.accent : Theme.fg
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: tItemHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.tgtCurrentIndex = index
                        root.targetLang = tgtLangModel.get(index).code
                        tgtDropdown.visible = false
                    }
                }
            }
        }
    }
}
