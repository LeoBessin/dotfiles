import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

PanelWindow {
    id: root

    property var modelData
    screen: modelData

    anchors.left:   true
    anchors.right:  true
    anchors.top:    true
    anchors.bottom: true

    property bool isActive: LauncherState.active && LauncherState.targetScreen === modelData

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "quickshell-launcher"
    WlrLayershell.keyboardFocus: isActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    color: "transparent"
    surfaceFormat.opaque: false

    Component.onCompleted: exclusionMode = ExclusionMode.Ignore

    visible: false

    onIsActiveChanged: {
        if (isActive) {
            root.visible     = true
            searchInput.text = ""
            _searchText      = ""
            hideTimer.stop()
            root.wallpaperPath = ""
            wallpaperReader.running = false
            wallpaperReader.running = true
            _rebuildFilter()
            focusTimer.restart()
        } else {
            hideTimer.restart()
        }
    }

    // Rebuild when async data arrives
    Connections {
        target: LauncherState
        function onModeChanged() {
            if (!root.isActive) return
            filterDebounce.stop()
            searchInput.text = ""
            _searchText = ""
            _rebuildFilter()
        }
        function onWindowLoadedChanged() { if (LauncherState.mode === "window") _rebuildFilter() }
        function onFileLoadedChanged()   { if (LauncherState.mode === "files")  _rebuildFilter() }
        function onEmojiLoadedChanged()  { if (LauncherState.mode === "emoji")  _rebuildFilter() }
        function onIconLoadedChanged()   { if (LauncherState.mode === "icon")   _rebuildFilter() }
        function onClipLoadedChanged()   { if (LauncherState.mode === "clip")   _rebuildFilter() }
    }

    Timer { id: hideTimer;  interval: Theme.animFast + 20; onTriggered: root.visible = false }
    Timer { id: focusTimer; interval: 60; onTriggered: {
        if (LauncherState.mode !== "files") searchInput.forceActiveFocus()
    }}

    // ── Wallpaper ─────────────────────────────────────────────────────────
    property string wallpaperPath: ""

    Process {
        id: wallpaperReader
        command: ["bash", "-c", "cat \"$HOME/.local/share/wallpapers/.current\" 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: (line) => { if (line.trim() !== "") root.wallpaperPath = line.trim() }
        }
    }

    // ── Filtered model + search ───────────────────────────────────────────
    property string _searchText: ""

    ListModel { id: filteredModel }

    Timer {
        id: filterDebounce
        interval: 150
        onTriggered: {
            root._searchText = searchInput.text
            root._rebuildFilter()
        }
    }

    function _sourceModel() {
        switch (LauncherState.mode) {
            case "app":    return LauncherState.appModel
            case "window": return LauncherState.windowModel
            case "files":  return LauncherState.fileModel
            case "emoji":  return LauncherState.emojiModel
            case "icon":   return LauncherState.iconModel
            case "clip":   return LauncherState.clipModel
            default:       return null
        }
    }

    function _matches(item) {
        var q = _searchText.toLowerCase()
        if (q === "" || LauncherState.mode === "files") return true
        var hay = LauncherState.mode === "clip"
            ? (item.preview ?? "").toLowerCase()
            : (item.name    ?? "").toLowerCase()
        return hay.includes(q)
    }

    function _rebuildFilter() {
        var src = _sourceModel()
        filteredModel.clear()
        if (src) {
            for (var i = 0; i < src.count; i++) {
                var item = src.get(i)
                if (_matches(item)) {
                    // All roles must be present on every item: QML ListModel fixes its
                    // role schema from the first append, so switching modes would make
                    // new roles invisible to delegates if we just did append(item).
                    filteredModel.append({
                        name:    item.name    ?? "",
                        icon:    item.icon    ?? "",
                        exec:    item.exec    ?? "",
                        title:   item.title   ?? "",
                        cls:     item.cls     ?? "",
                        address: item.address ?? "",
                        path:    item.path    ?? "",
                        isDir:   item.isDir   ?? false,
                        char:    item.char    ?? "",
                        preview: item.preview ?? "",
                        id:      item.id      ?? "",
                        line:    item.line    ?? ""
                    })
                }
            }
        }
        gridView.currentIndex = 0
        listView.currentIndex = 0
    }

    // ── Backdrop ──────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: LauncherState.close()
    }

    // ── Card ──────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        // Use screen dimensions for centering — root.height/width start at 100 (Qt default)
        // until the Wayland compositor sends its configure, so anchors.centerIn: parent
        // would misplace the card off-screen on every open after the first.
        x: Math.round((modelData.width  - width)  / 2)
        y: Math.round((modelData.height - height) / 2)
        width:  Theme.launcherWidth
        // Grow to fit the wallpaper's natural height + fixed content area,
        // but never taller than the available screen minus bar and margin.
        readonly property real _wallpaperH: wallpaperImg.implicitWidth > 0
            ? Math.round(wallpaperImg.implicitHeight * (Theme.launcherWidth / wallpaperImg.implicitWidth))
            : 161
        height: Math.min(
            _wallpaperH + 360,                          // header + content floor
            modelData.height - Theme.barHeight - 40     // screen cap (use screen size, not surface size which may be 0 on re-show)
        )
        radius: Theme.launcherRadius
        color:  "transparent"

        scale:   root.isActive ? 1.0 : 0.96
        opacity: root.isActive ? 1.0 : 0.0
        Behavior on scale   { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        MouseArea { anchors.fill: parent }

        Keys.onEscapePressed: LauncherState.close()

        // ── Wallpaper header ──────────────────────────────────────────────
        // Height = natural proportional height at card width (full image, no crop).
        // Capped so the content area keeps at least 3 grid rows / 8 list rows.
        Item {
            id: headerRect
            anchors.top:   parent.top
            anchors.left:  parent.left
            anchors.right: parent.right
            readonly property real _naturalH: wallpaperImg.implicitWidth > 0
                ? Math.round(wallpaperImg.implicitHeight * (card.width / wallpaperImg.implicitWidth))
                : 161
            // Leave at least 360px for content (40 margins + 42 search + 14 gap + 264 = 3-row grid)
            height: root.wallpaperPath !== "" ? Math.min(_naturalH, card.height - 360) : 0
            clip: true

            // Solid background (visible in the rounded corner cut-outs and when no wallpaper)
            Rectangle {
                anchors.fill: parent
                color: Theme.bgSolid
                topLeftRadius:  Theme.launcherRadius
                topRightRadius: Theme.launcherRadius
            }

            // Source image — hidden, rendered via MultiEffect below
            Image {
                id: wallpaperImg
                width:  card.width
                height: implicitWidth > 0
                        ? Math.round(implicitHeight * (card.width / implicitWidth))
                        : headerRect.height
                anchors.top:              parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                source:       root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""
                fillMode:     Image.Stretch
                asynchronous: true
                smooth:       true
                visible:      false
            }

            // Mask shape: white fill with rounded top corners — used as alpha mask
            Rectangle {
                id: wallpaperMask
                width:  wallpaperImg.width
                height: wallpaperImg.height
                anchors.top:              parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                topLeftRadius:  Theme.launcherRadius
                topRightRadius: Theme.launcherRadius
                layer.enabled: true
                visible: false
            }

            MultiEffect {
                source:   wallpaperImg
                width:    wallpaperImg.width
                height:   wallpaperImg.height
                anchors.top:              parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                visible:            root.wallpaperPath !== ""
                autoPaddingEnabled: false
                maskEnabled:        true
                maskSource:         wallpaperMask
                maskThresholdMin:   0.5
                maskSpreadAtMin:    1.0
            }
        }

        // ── Mainbox ───────────────────────────────────────────────────────
        Rectangle {
            anchors.top:    headerRect.bottom
            anchors.bottom: parent.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            color:  Theme.launcherBg
            bottomLeftRadius:  Theme.launcherRadius
            bottomRightRadius: Theme.launcherRadius
            topLeftRadius:  headerRect.height > 0 ? 0 : Theme.launcherRadius
            topRightRadius: headerRect.height > 0 ? 0 : Theme.launcherRadius

            ColumnLayout {
                anchors {
                    fill:         parent
                    topMargin:    20
                    bottomMargin: 20
                    leftMargin:   20
                    rightMargin:  20
                }
                spacing: 14

                // ── Search / path bar ─────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 42
                    radius: Theme.radius
                    color:  Theme.launcherBgInput
                    border.color: Theme.launcherBorder
                    border.width: 1

                    RowLayout {
                        anchors {
                            fill:        parent
                            leftMargin:  16
                            rightMargin: 12
                        }
                        spacing: 10

                        // Back button — files mode only
                        Rectangle {
                            visible: LauncherState.mode === "files"
                            width:  24; height: 24
                            radius: Theme.pillRadius
                            color:  backMouse.containsMouse ? Theme.bgHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.family:    Theme.iconFamily
                                font.pixelSize: Theme.iconSize
                                color: Theme.launcherFgDim
                            }

                            MouseArea {
                                id: backMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: _navigateUp()
                            }
                        }

                        // Mode prompt label
                        Text {
                            visible: LauncherState.mode !== "files"
                            text: {
                                switch (LauncherState.mode) {
                                    case "app":    return "Open"
                                    case "window": return "Window"
                                    case "emoji":  return "Emoji"
                                    case "icon":   return "Icon"
                                    case "clip":   return "Copy"
                                    default:       return ""
                                }
                            }
                            font.family:    Theme.monoFamily
                            font.pixelSize: Theme.fontSize
                            color:          Theme.launcherFgDim
                        }

                        // Path breadcrumb — files mode
                        Text {
                            visible:   LauncherState.mode === "files"
                            text:      LauncherState.currentDir
                            font.family:    Theme.monoFamily
                            font.pixelSize: Theme.fontSize - 1
                            color:          Theme.launcherFg
                            elide:          Text.ElideLeft
                            Layout.fillWidth: true
                        }

                        // Search input — all other modes
                        TextInput {
                            id: searchInput
                            visible:   LauncherState.mode !== "files"
                            Layout.fillWidth: true
                            color:            Theme.launcherFg
                            font.family:      Theme.monoFamily
                            font.pixelSize:   Theme.fontSize
                            cursorVisible:    activeFocus
                            selectionColor:   Qt.rgba(0.92, 0.44, 0.57, 0.35)
                            clip:             true

                            Keys.onUpPressed: {
                                if (LauncherState.mode === "app") gridView.moveCurrentIndexUp()
                                else listView.decrementCurrentIndex()
                            }
                            Keys.onDownPressed: {
                                if (LauncherState.mode === "app") gridView.moveCurrentIndexDown()
                                else listView.incrementCurrentIndex()
                            }
                            Keys.onLeftPressed: (event) => {
                                if (LauncherState.mode === "app") gridView.moveCurrentIndexLeft()
                                else event.accepted = false
                            }
                            Keys.onRightPressed: (event) => {
                                if (LauncherState.mode === "app") gridView.moveCurrentIndexRight()
                                else event.accepted = false
                            }
                            Keys.onReturnPressed: {
                                var idx = LauncherState.mode === "app"
                                    ? gridView.currentIndex
                                    : listView.currentIndex
                                _confirmAt(idx)
                            }
                            Keys.onEscapePressed: LauncherState.close()

                            onTextChanged: filterDebounce.restart()

                            Text {
                                visible: searchInput.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    switch (LauncherState.mode) {
                                        case "app":    return "Search apps..."
                                        case "window": return "Search windows..."
                                        case "emoji":  return "Search emoji..."
                                        case "icon":   return "Search icons..."
                                        case "clip":   return "Search history..."
                                        default:       return "Search..."
                                    }
                                }
                                font:  searchInput.font
                                color: Theme.launcherFgDim
                            }
                        }
                    }
                }

                // ── Content area ──────────────────────────────────────────
                Item {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    clip: true

                    // App launcher — 4-column grid
                    GridView {
                        id: gridView
                        anchors.fill: parent
                        visible:      LauncherState.mode === "app"

                        cellWidth:  Math.floor(width / 4)
                        cellHeight: 88
                        model:      filteredModel

                        highlight: Rectangle {
                            radius: Theme.pillRadius
                            color:  Theme.launcherBgSelected
                        }
                        highlightFollowsCurrentItem: true
                        highlightMoveDuration: Theme.animFast

                        Keys.onUpPressed:    moveCurrentIndexUp()
                        Keys.onDownPressed:  moveCurrentIndexDown()
                        Keys.onLeftPressed:  moveCurrentIndexLeft()
                        Keys.onRightPressed: moveCurrentIndexRight()
                        Keys.onReturnPressed: _confirmAt(currentIndex)
                        Keys.onEscapePressed: LauncherState.close()

                        delegate: Item {
                            required property var model
                            required property int index
                            width:  gridView.cellWidth
                            height: gridView.cellHeight

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked:    _confirmAt(index)
                                onEntered:    gridView.currentIndex = index
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 32; height: 32

                                    Image {
                                        id: appIcon
                                        anchors.fill: parent
                                        source: {
                                            var ic = model.icon ?? ""
                                            if (ic === "") return ""
                                            if (ic.startsWith("/")) return "file://" + ic
                                            return "image://icon/" + ic
                                        }
                                        sourceSize:   Qt.size(32, 32)
                                        fillMode:     Image.PreserveAspectFit
                                        smooth:       true
                                        visible:      (model.icon ?? "") !== "" && status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: (model.icon ?? "") === "" || appIcon.status !== Image.Ready
                                        text: ""
                                        font.family:    Theme.iconFamily
                                        font.pixelSize: 26
                                        color: Theme.launcherFgDim
                                    }
                                }

                                Text {
                                    Layout.alignment:    Qt.AlignHCenter
                                    Layout.maximumWidth: gridView.cellWidth - 8
                                    text:  model.name ?? ""
                                    font.family:    Theme.monoFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    color: Theme.launcherFg
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    }

                    // List view — window / files / emoji / icon / clip
                    ListView {
                        id: listView
                        anchors.fill: parent
                        visible:      LauncherState.mode !== "app"
                        clip: true
                        spacing: 2
                        model: filteredModel

                        highlight: Rectangle {
                            radius: Theme.pillRadius
                            color:  Theme.launcherBgSelected
                        }
                        highlightFollowsCurrentItem: true
                        highlightMoveDuration: Theme.animFast

                        Keys.onUpPressed:    decrementCurrentIndex()
                        Keys.onDownPressed:  incrementCurrentIndex()
                        Keys.onReturnPressed: _confirmAt(currentIndex)
                        Keys.onEscapePressed: LauncherState.close()
                        Keys.onBackPressed: {
                            if (LauncherState.mode === "files") _navigateUp()
                        }

                        delegate: Item {
                            required property var model
                            required property int index
                            width:  listView.width
                            height: 40

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked:    _confirmAt(index)
                                onEntered:    listView.currentIndex = index
                            }

                            RowLayout {
                                anchors {
                                    fill:        parent
                                    leftMargin:  10
                                    rightMargin: 10
                                }
                                spacing: 10

                                // Left glyph
                                Item {
                                    width: 28; height: 28
                                    Layout.alignment: Qt.AlignVCenter

                                    Image {
                                        anchors.centerIn: parent
                                        visible: LauncherState.mode === "window"
                                        width: 20; height: 20
                                        source:     (model.cls ?? "") !== "" ? "image://icon/" + model.cls : ""
                                        sourceSize: Qt.size(20, 20)
                                        fillMode:   Image.PreserveAspectFit
                                        smooth:     true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: LauncherState.mode === "files"
                                        text:  (model.name === "..") ? ""
                                             : model.isDir            ? ""
                                             :                          ""
                                        font.family:    Theme.iconFamily
                                        font.pixelSize: Theme.iconSize + 2
                                        color: model.isDir ? Theme.launcherAccentAlt : Theme.launcherFgDim
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: LauncherState.mode === "emoji" || LauncherState.mode === "icon"
                                        text:  model.char ?? ""
                                        font.family:    LauncherState.mode === "icon" ? Theme.nerdFamily : Theme.emojiFamily
                                        font.pixelSize: 20
                                        color: Theme.launcherFg
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: LauncherState.mode === "clip"
                                        text: ""
                                        font.family:    Theme.iconFamily
                                        font.pixelSize: Theme.iconSize
                                        color: Theme.launcherFgDim
                                    }
                                }

                                // Main label
                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        switch (LauncherState.mode) {
                                            case "window": return model.title   ?? ""
                                            case "files":  return model.name    ?? ""
                                            case "emoji":
                                            case "icon":   return model.name    ?? ""
                                            case "clip":   return model.preview ?? ""
                                            default:       return ""
                                        }
                                    }
                                    font.family:    Theme.monoFamily
                                    font.pixelSize: Theme.fontSize
                                    color: Theme.launcherFg
                                    elide: Text.ElideRight
                                }

                                // Window class chip
                                Rectangle {
                                    visible: LauncherState.mode === "window" && (model.cls ?? "") !== ""
                                    implicitWidth:  clsLabel.implicitWidth + 10
                                    height: 18
                                    radius: 4
                                    color:  Qt.rgba(0.92, 0.44, 0.57, 0.12)

                                    Text {
                                        id: clsLabel
                                        anchors.centerIn: parent
                                        text:  model.cls ?? ""
                                        font.family:    Theme.monoFamily
                                        font.pixelSize: Theme.fontSize - 2
                                        color: Theme.launcherAccent
                                    }
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        // Loading indicator
                        Text {
                            anchors.centerIn: parent
                            visible: (LauncherState.mode === "emoji" && !LauncherState.emojiLoaded && filteredModel.count === 0) ||
                                     (LauncherState.mode === "icon"  && !LauncherState.iconLoaded  && filteredModel.count === 0)
                            text:  "Loading…"
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            color: Theme.launcherFgDim
                        }
                    }
                }
            }
        }

        // ── Border overlay (on top of all children so it isn't painted over) ──
        Rectangle {
            anchors.fill: parent
            radius: Theme.launcherRadius
            color: "transparent"
            border.color: Theme.launcherBorder
            border.width: 1
        }
    }

    // ── Action processes ──────────────────────────────────────────────────
    Process { id: appRunner }
    Process { id: winFocuser }
    Process { id: fileOpener }
    Process { id: charCopier }
    Process { id: clipRestorer }

    // ── Actions ───────────────────────────────────────────────────────────
    function _confirmAt(idx) {
        var item = filteredModel.get(idx)
        if (!item) return
        var m = LauncherState.mode

        if (m === "app") {
            if (!item.exec || item.exec.trim() === "") return
            appRunner.command = ["bash", "-c", item.exec + " &"]
            appRunner.running = false
            appRunner.running = true
            LauncherState.close()

        } else if (m === "window") {
            winFocuser.command = ["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + item.address + "\" })"]
            winFocuser.running = false
            winFocuser.running = true
            LauncherState.close()

        } else if (m === "files") {
            if (item.isDir) {
                LauncherState.navigateFiles(item.path)
            } else {
                fileOpener.command = ["xdg-open", item.path]
                fileOpener.running = false
                fileOpener.running = true
                LauncherState.close()
            }

        } else if (m === "emoji" || m === "icon") {
            charCopier.command = ["wl-copy", item.char]
            charCopier.running = false
            charCopier.running = true
            LauncherState.close()

        } else if (m === "clip") {
            clipRestorer.command = ["bash", "-c",
                "printf '%s' " + JSON.stringify(item.id) + " | cliphist decode | wl-copy"]
            clipRestorer.running = false
            clipRestorer.running = true
            LauncherState.close()
        }
    }

    function _navigateUp() {
        var cur = LauncherState.currentDir
        if (cur === "/" || cur === "") return
        var par = cur.substring(0, cur.lastIndexOf("/"))
        if (par === "") par = "/"
        LauncherState.navigateFiles(par)
    }
}
