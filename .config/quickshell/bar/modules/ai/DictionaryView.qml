import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import ".."

Item {
    id: root

    // ── Supported Wiktionary languages ────────────────────────────────────
    readonly property var languages: [
        { code: "en", label: "English" },
        { code: "fr", label: "French" },
        { code: "de", label: "German" },
        { code: "es", label: "Spanish" },
        { code: "it", label: "Italian" },
        { code: "pt", label: "Portuguese" },
        { code: "ru", label: "Russian" },
        { code: "ja", label: "Japanese" },
        { code: "zh", label: "Chinese" },
        { code: "ar", label: "Arabic" },
        { code: "pl", label: "Polish" },
        { code: "nl", label: "Dutch" }
    ]

    property int  langIndex: 0
    property bool loading:   false
    property ListModel history: ListModel {}

    // ── Wiktionary text → HTML formatter ─────────────────────────────────
    function formatDefinition(raw) {
        if (!raw || raw === "…") return raw

        // Parts of speech that get the badge treatment
        var posTitles = ["Noun","Verb","Adjective","Adverb","Pronoun","Preposition",
                         "Conjunction","Interjection","Phrase","Suffix","Prefix",
                         "Determiner","Numeral","Particle","Article","Symbol","Letter",
                         "Proper noun","Contraction","Verb form",
                         // French
                         "Verbe","Nom","Adjectif","Adverbe","Pronom","Préposition",
                         "Conjonction","Interjection","Locution",
                         // German/Spanish/Portuguese
                         "Substantiv","Adjektiv","Adverb","Verb","Sustantivo"]

        // Sections to suppress entirely (navigation noise)
        var skipTitles = ["Anagrammes","Anagrams","Translations","Traductions",
                          "Further reading","See also","References","External links",
                          "Collocations","Vocabulary","Conjugation","Conjugaison",
                          "Declension","Inflection","Quotations"]

        function isPOS(t) {
            for (var i = 0; i < posTitles.length; i++)
                if (t.indexOf(posTitles[i]) >= 0) return true
            return false
        }
        function shouldSkip(t) {
            for (var i = 0; i < skipTitles.length; i++)
                if (t.indexOf(skipTitles[i]) >= 0) return true
            return false
        }

        function esc(s) {
            return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
        }

        // Dim text in (parentheses) — grammar/register annotations
        function dimParens(s) {
            return esc(s).replace(/(\([^)]+\))/g,
                '<span style="color:#8080a8;">$1</span>')
        }

        // ── Parse into sections ──────────────────────────────────────────
        var lines = raw.split('\n')
        var sections = []
        var cur = null

        for (var li = 0; li < lines.length; li++) {
            var line = lines[li]
            var m4 = /^====\s*(.+?)\s*====\s*$/.exec(line)
            var m3 = !m4 ? /^===\s*(.+?)\s*===\s*$/.exec(line)  : null
            var m2 = !m4 && !m3 ? /^==\s*(.+?)\s*==\s*$/.exec(line) : null

            if (m4)      { cur = { lvl:4, title:m4[1], lines:[] }; sections.push(cur) }
            else if (m3) { cur = { lvl:3, title:m3[1], lines:[] }; sections.push(cur) }
            else if (m2) { cur = { lvl:2, title:m2[1], lines:[] }; sections.push(cur) }
            else if (cur) cur.lines.push(line)
        }

        // Drop empty non-language sections and suppressed titles
        sections = sections.filter(function(s) {
            if (s.lvl === 2) return true
            if (shouldSkip(s.title)) return false
            return s.lines.some(function(l) { return l.trim().length > 0 })
        })

        // ── Render HTML ──────────────────────────────────────────────────
        var html = ''
        var firstLang = true

        for (var si = 0; si < sections.length; si++) {
            var sec = sections[si]
            var nonempty = sec.lines.filter(function(l) { return l.trim().length > 0 })

            // ── Level 2: language header ─────────────────────────────────
            if (sec.lvl === 2) {
                if (!firstLang)
                    html += '<p style="margin:0;"> </p>'
                firstLang = false
                html += '<p style="margin:0 0 1px 0;">'
                html += '<span style="font-size:14px;font-weight:600;color:#b39ddb;">'
                html += esc(sec.title)
                html += '</span></p>'
                html += '<p style="margin:0 0 7px 0;color:#3d3060;">──────────────────────</p>'

            // ── Level 3: named section ───────────────────────────────────
            } else if (sec.lvl === 3) {

                if (isPOS(sec.title)) {
                    // Part-of-speech badge + definitions
                    html += '<p style="margin:7px 0 3px 0;">'
                    html += '<span style="color:#c5b8f0;font-weight:600;background-color:#2a2048;padding:1px 5px;border-radius:3px;">'
                    html += esc(sec.title)
                    html += '</span></p>'

                    if (nonempty.length > 0) {
                        // First non-empty line: headword (bold) + grammar info (dim)
                        var hw = nonempty[0].trim()
                        // Split at first ( or \  — whichever comes first after the word
                        var splitAt = hw.length
                        var pi = hw.indexOf('('), si2 = hw.indexOf('\\')
                        if (pi > 0 && pi < splitAt) splitAt = pi
                        if (si2 > 0 && si2 < splitAt) splitAt = si2
                        var wordPart = hw.slice(0, splitAt).trim()
                        var infoPart = splitAt < hw.length ? hw.slice(splitAt).trim() : ''

                        html += '<p style="margin:0 0 4px 0;">'
                        html += '<b style="color:#e8e8f8;font-size:13px;">' + esc(wordPart) + '</b>'
                        if (infoPart)
                            html += '&nbsp;<span style="color:#8080a8;font-size:11px;">' + esc(infoPart) + '</span>'
                        html += '</p>'

                        // Remaining lines: definitions as bullet points
                        for (var di = 1; di < nonempty.length; di++) {
                            html += '<p style="margin:1px 0 1px 10px;">'
                            html += '<span style="color:#6060a0;">&#x2022;</span>&nbsp;'
                            html += dimParens(nonempty[di].trim())
                            html += '</p>'
                        }
                    }

                } else if (sec.title.indexOf('Pronunciation') >= 0 ||
                           sec.title.indexOf('Prononciation') >= 0 ||
                           sec.title.indexOf('Aussprache') >= 0) {
                    // Pronunciation section
                    html += '<p style="margin:7px 0 2px 0;">'
                    html += '<span style="font-size:10px;font-weight:600;color:#7070a0;letter-spacing:1px;">PRONUNCIATION</span>'
                    html += '</p>'

                    for (var pron_i = 0; pron_i < nonempty.length; pron_i++) {
                        var pl = nonempty[pron_i].trim()
                        if (/^(Rhymes|Hyphen|Audio|Homophones|Homophone)/.test(pl)) continue
                        // French pronunciation lines like "France (Vosges) : écouter…" — skip audio refs
                        if (/écouter|ecouter|listen/.test(pl)) continue

                        var ipaM = pl.match(/IPA(?:\(key\))?:\s*(.+)/)
                        if (ipaM) {
                            var pre = pl.slice(0, pl.indexOf('IPA')).trim().replace(/:$/, '').trim()
                            html += '<p style="margin:1px 0;">'
                            if (pre)
                                html += '<span style="color:#8080a8;font-size:11px;">' + esc(pre) + '&ensp;</span>'
                            html += '<span style="font-family:monospace;color:#c8c0e8;">' + esc(ipaM[1]) + '</span>'
                            html += '</p>'
                        } else {
                            html += '<p style="margin:1px 0;color:#9090b0;font-size:11px;">' + esc(pl) + '</p>'
                        }
                    }

                } else {
                    // Generic section (Etymology, Alternative forms, etc.)
                    html += '<p style="margin:7px 0 2px 0;">'
                    html += '<span style="font-size:10px;font-weight:600;color:#7070a0;letter-spacing:1px;">'
                    html += esc(sec.title.toUpperCase())
                    html += '</span></p>'

                    if (sec.title.indexOf('Alternative') >= 0 ||
                        sec.title.indexOf('Formes') >= 0) {
                        // Alternative forms: comma list
                        html += '<p style="margin:0;color:#b0b0c8;">'
                        html += nonempty.map(function(l){ return esc(l.trim()) }).join(',&ensp;')
                        html += '</p>'
                    } else {
                        // Etymology, notes, etc.: flowing paragraph
                        html += '<p style="margin:0;color:#b0b0c8;line-height:150%;">'
                        html += dimParens(nonempty.map(function(l){ return l.trim() }).join(' '))
                        html += '</p>'
                    }
                }

            // ── Level 4: subsection (Synonyms, Antonyms, etc.) ───────────
            } else if (sec.lvl === 4) {
                html += '<p style="margin:5px 0 1px 6px;">'
                html += '<span style="font-size:10px;color:#7070a0;letter-spacing:1px;">'
                html += esc(sec.title.toUpperCase())
                html += '</span></p>'
                html += '<p style="margin:0 0 0 6px;color:#b0b0c8;">'
                html += nonempty.map(function(l){ return esc(l.trim()) }).join(',&ensp;')
                html += '</p>'
            }
        }

        return html || raw
    }

    // ── Lookup ────────────────────────────────────────────────────────────
    function doLookup() {
        var word = inputArea.text.trim()
        if (!word || loading) return

        history.append({ word: word, definition: "…", rawDef: "" })
        var idx  = history.count - 1
        var lang = languages[langIndex]
        inputArea.text = ""
        loading = true

        var encoded = encodeURIComponent(word)
        var url = "https://" + lang.code + ".wiktionary.org/w/api.php"
                + "?action=query&titles=" + encoded
                + "&prop=extracts&explaintext=true&format=json"

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            loading = false
            var rawText
            if (xhr.status === 200) {
                try {
                    var data  = JSON.parse(xhr.responseText)
                    var pages = data.query.pages
                    var pid   = Object.keys(pages)[0]
                    var page  = pages[pid]
                    if (pid === "-1" || page.hasOwnProperty("missing")) {
                        rawText = "(word not found in " + lang.label + " Wiktionary)"
                    } else {
                        rawText = (page.extract || "").trim() || "(no definition available)"
                    }
                } catch(e) {
                    rawText = "(error parsing response)"
                }
            } else {
                rawText = "(network error " + xhr.status + ")"
            }
            history.setProperty(idx, "rawDef",    rawText)
            history.setProperty(idx, "definition", root.formatDefinition(rawText))
            Qt.callLater(() => histView.positionViewAtEnd())
        }
        xhr.open("GET", url)
        xhr.send()
        Qt.callLater(() => histView.positionViewAtEnd())
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
            z: langDropdown.visible ? 2 : 0

            RowLayout {
                anchors { fill: parent; margins: 10 }
                spacing: 8

                Text {
                    text: "Wiktionary:"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fgDim
                }

                Rectangle {
                    id: langBtn
                    Layout.preferredWidth: 130
                    height: 26
                    radius: Theme.pillRadius
                    color: langBtnArea.containsMouse ? Theme.bgHover : Qt.rgba(1,1,1,0.04)
                    border.color: langDropdown.visible ? Theme.notifBorderBase : Theme.notifBorderMid
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: root.languages[root.langIndex].label
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            color: Theme.fg
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: langDropdown.visible ? "expand_less" : "expand_more"
                            font.family:    Theme.iconFamily
                            font.pixelSize: 13
                            color: Theme.fgDim
                        }
                    }
                    MouseArea {
                        id: langBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (langDropdown.visible) { langDropdown.visible = false; return }
                            var p = langBtn.mapToItem(root, 0, langBtn.height + 2)
                            langDropdown.x = p.x
                            langDropdown.y = p.y
                            langDropdown.visible = true
                        }
                    }
                }

                Item { Layout.fillWidth: true }
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

                        // Word bubble (right)
                        Item {
                            width: parent.width
                            height: wordBubble.height

                            Rectangle {
                                id: wordBubble
                                anchors.right: parent.right
                                width: Math.min(wordText.implicitWidth + 20, parent.width * 0.7)
                                height: wordText.contentHeight + 16
                                radius: Theme.pillRadius
                                color: Qt.rgba(0.44, 0.39, 0.68, 0.35)
                                border.color: Qt.rgba(0.70, 0.62, 0.86, 0.25)
                                border.width: 1

                                TextEdit {
                                    id: wordText
                                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 10; rightMargin: 10; topMargin: 8 }
                                    text: model.word
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

                        // Definition bubble (left)
                        Item {
                            width: parent.width
                            height: defBubble.height

                            Rectangle {
                                id: defBubble
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                width: model.definition !== "…"
                                       ? parent.width - 6
                                       : Math.min(defText.implicitWidth + 20, parent.width * 0.5)
                                height: defText.contentHeight + 16
                                radius: Theme.pillRadius
                                color: Theme.notifCardBg
                                border.color: Theme.notifBorderDim
                                border.width: 1

                                TextEdit {
                                    id: defText
                                    anchors {
                                        left: parent.left; right: parent.right; top: parent.top
                                        leftMargin: 12; rightMargin: 12; topMargin: 8
                                    }
                                    text: model.definition
                                    textFormat: model.definition.charAt(0) === '<'
                                                ? TextEdit.RichText : TextEdit.PlainText
                                    readOnly: true
                                    selectByMouse: true
                                    selectedTextColor: Theme.bgSolid
                                    selectionColor:    Theme.accent
                                    font.family:    Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    color: model.definition === "…" ? Theme.fgDim : Theme.fg
                                    wrapMode: TextEdit.Wrap
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
            property real pillHeight: Math.min(Math.max(inputArea.contentHeight + 14, 36), 100)
            Layout.preferredHeight: pillHeight + 16
            color: "transparent"

            RowLayout {
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
                            placeholderText: "Enter a word to look up…"
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
                                    root.doLookup()
                                }
                            }
                        }
                    }
                }

                // Lookup button
                Rectangle {
                    width: 36; height: 36
                    radius: Theme.pillRadius
                    color: lookupHov.containsMouse ? Theme.accentDim : Theme.accent
                    opacity: root.loading ? 0.5 : 1.0
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: root.loading ? "hourglass_empty" : "search"
                        font.family:    Theme.iconFamily
                        font.pixelSize: 18
                        color: Theme.bgSolid
                    }

                    MouseArea {
                        id: lookupHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.loading
                        onClicked: root.doLookup()
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
                        onClicked: root.history.clear()
                    }
                }
            }
        }
    }

    // ── Language dropdown overlay ─────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: langDropdown.visible
        z: 9
        onClicked: langDropdown.visible = false
    }

    Rectangle {
        id: langDropdown
        visible: false
        z: 10
        width: 160
        height: Math.min(langDropList.contentHeight + 8, 260)
        radius: Theme.pillRadius
        color: Theme.bgSolid
        border.color: Theme.notifBorderBase
        border.width: 1
        clip: true

        onVisibleChanged: {
            if (visible) {
                langDropList.currentIndex = root.langIndex
                langDropList.positionViewAtIndex(root.langIndex, ListView.Contain)
                langDropList.forceActiveFocus()
            }
        }

        ListView {
            id: langDropList
            anchors { fill: parent; margins: 4 }
            model: root.languages.length
            keyNavigationEnabled: true
            highlightMoveDuration: 0
            currentIndex: -1
            highlight: Rectangle { color: Theme.notifHoverBg; radius: 4 }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (currentIndex >= 0) root.langIndex = currentIndex
                    langDropdown.visible = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    langDropdown.visible = false
                    event.accepted = true
                } else if (event.text.length === 1 && /[a-zA-Z]/.test(event.text)) {
                    var lower = event.text.toLowerCase()
                    var cnt = root.languages.length
                    var start = (currentIndex + 1 + cnt) % cnt
                    for (var i = 0; i < cnt; i++) {
                        var idx = (start + i) % cnt
                        if (root.languages[idx].label.charAt(0).toLowerCase() === lower) {
                            currentIndex = idx
                            positionViewAtIndex(idx, ListView.Contain)
                            break
                        }
                    }
                    event.accepted = true
                }
            }

            delegate: Rectangle {
                width: langDropList.width
                height: 26
                color: lItemHov.containsMouse ? Theme.notifHoverBg : "transparent"
                radius: 4
                Text {
                    anchors { fill: parent; leftMargin: 8 }
                    text: root.languages[index].label
                    color: root.langIndex === index ? Theme.accent : Theme.fg
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: lItemHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.langIndex = index
                        langDropdown.visible = false
                    }
                }
            }
        }
    }
}
