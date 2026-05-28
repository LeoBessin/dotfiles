import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "."

PanelWindow {
    id: root

    property var modelData
    screen: modelData

    anchors.left:   true
    anchors.right:  true
    anchors.top:    true
    anchors.bottom: true

    property bool isActive: NotifService.centerOpen && NotifService.targetScreen === modelData

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "quickshell-notif-center"
    WlrLayershell.keyboardFocus: root.isActive
                                 ? WlrKeyboardFocus.OnDemand
                                 : WlrKeyboardFocus.None

    color: "transparent"
    surfaceFormat.opaque: false

    Component.onCompleted: exclusionMode = ExclusionMode.Ignore

    visible: false
    onVisibleChanged: if (!visible && root.isActive) NotifService.centerOpen = false

    readonly property int usageCacheMs: 60000

    onIsActiveChanged: {
        if (root.isActive) {
            root.visible = true
            hideTimer.stop()
            markReadTimer.restart()
            panelContent.activeTab = 0
            if (Date.now() - panelContent.claudeLastFetch > root.usageCacheMs) {
                claudeUsageFetcher.running = false
                claudeUsageFetcher.running = true
            }
            if (Date.now() - panelContent.copilotLastFetch > root.usageCacheMs) {
                copilotUsageFetcher.running = false
                copilotUsageFetcher.running = true
            }
        } else {
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: Theme.animMed + 20
        onTriggered: root.visible = false
    }

    Timer {
        id: markReadTimer
        interval: 800
        onTriggered: NotifService.markAllRead()
    }

    // ── Backdrop ──────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: NotifService.closeCenter()
    }

    // ── Slide-in panel ────────────────────────────────────────────────────
    Rectangle {
        id: panelContent
        anchors.top:         parent.top
        anchors.bottom:      parent.bottom
        anchors.right:       parent.right
        anchors.topMargin:   Theme.barHeight + 6
        anchors.rightMargin: root.isActive ? 8 : -width

        width: 380

        opacity: root.isActive ? 1.0 : 0.0

        Behavior on anchors.rightMargin {
            NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.animFast }
        }

        // color:        Qt.rgba(0.10, 0.09, 0.15, 0.55)
        color:        Qt.rgba(0.10, 0.09, 0.15, 0.85)
        radius:       Theme.radius
        border.color: Qt.rgba(0.70, 0.62, 0.86, 0.20)
        border.width: 1

        MouseArea { anchors.fill: parent }

        // Active tab index: 0=Notifications, 1=Caffeine, 2=Calendar, 3=Settings
        property int activeTab: 0

        property real settingsVolume:        0
        property bool settingsMuted:         false
        property real settingsBrightness:    50
        property int  settingsBrightnessMax: 100

        property ListModel wallpaperModel: ListModel {}
        property string    currentWallpaper: ""

        // ── Settings tab: volume state ────────────────────────────────────
        function refreshVolume() {
            volumeFetcherSettings.running = false
            volumeFetcherSettings.running = true
        }

        Component.onCompleted: {
            refreshVolume()
            brightGetCurrent.running = true
            brightGetMax.running     = true
        }

        onActiveTabChanged: {
            if (activeTab === 3) {
                refreshVolume()
                brightGetCurrent.running = true
            }
        }

        Process {
            id: volumeFetcherSettings
            command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
            stdout: SplitParser {
                onRead: (line) => {
                    var m = line.match(/Volume:\s*([\d.]+)(\s+\[MUTED\])?/)
                    if (m) {
                        panelContent.settingsVolume = Math.round(parseFloat(m[1]) * 100)
                        panelContent.settingsMuted  = !!m[2]
                    }
                }
            }
        }

        Process {
            id: pactlSubscribeSettings
            command: ["bash", "-c", "pactl subscribe | grep --line-buffered -E \"'(change|new|remove)' on (sink|server)\""]
            running: true
            stdout: SplitParser {
                onRead: (_) => panelContent.refreshVolume()
            }
        }

        Process {
            id: volumeSetSettings
            command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "50%"]
            onRunningChanged: if (!running) panelContent.refreshVolume()
        }

        Process {
            id: brightGetCurrent
            command: ["brightnessctl", "get"]
            stdout: SplitParser {
                onRead: (line) => {
                    var v = parseInt(line.trim())
                    if (!isNaN(v) && panelContent.settingsBrightnessMax > 0)
                        panelContent.settingsBrightness = Math.round((v / panelContent.settingsBrightnessMax) * 100)
                }
            }
        }

        Process {
            id: brightGetMax
            command: ["brightnessctl", "max"]
            stdout: SplitParser {
                onRead: (line) => {
                    var v = parseInt(line.trim())
                    if (!isNaN(v)) panelContent.settingsBrightnessMax = v
                }
            }
        }

        Process {
            id: brightSetSettings
            command: ["brightnessctl", "set", "50%"]
            onExited: brightGetCurrent.running = true
        }

        Process {
            id: wallpaperLister
            command: ["sh", "-c",
                "find \"$HOME/.local/share/wallpapers\" -maxdepth 1 -type f " +
                "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
                "| sort"
            ]
            stdout: SplitParser {
                onRead: (line) => {
                    if (line.trim() !== "")
                        panelContent.wallpaperModel.append({ path: line.trim() })
                }
            }
        }

        Process {
            id: wallpaperCurrentReader
            command: ["sh", "-c", "cat \"$HOME/.local/share/wallpapers/.current\" 2>/dev/null || true"]
            stdout: SplitParser {
                onRead: (line) => { if (line.trim() !== "") panelContent.currentWallpaper = line.trim() }
            }
        }

        Process {
            id: wallpaperApplier
        }

        // ── Claude usage state ────────────────────────────────────────────
        property real   claudeFiveHour:        0
        property real   claudeSevenDay:        0
        property real   claudeCredits:         0
        property string claudeFiveHourResetsAt: ""
        property string claudeSevenDayResetsAt: ""
        property bool   claudeLoading:         false
        property real   claudeLastFetch:       0   // ms timestamp

        // ── Copilot usage state ───────────────────────────────────────────
        property real   copilotPremiumRemaining: 0
        property real   copilotPremiumTotal:     300
        property string copilotResetDate:        ""
        property bool   copilotLoading:          false
        property real   copilotLastFetch:        0   // ms timestamp

        Process {
            id: copilotUsageFetcher
            command: ["bash", "-c",
                "TOKEN=$(jq -r 'to_entries[0].value.oauth_token // empty' \"$HOME/.config/github-copilot/apps.json\"); " +
                "curl -s -H \"Authorization: Bearer $TOKEN\" -H \"Editor-Version: vscode/1.90.0\" " +
                "https://api.github.com/copilot_internal/user | " +
                "jq -r '\"\\(.quota_snapshots.premium_interactions.remaining) \\(.quota_snapshots.premium_interactions.entitlement) \\(.quota_reset_date)\"'"
            ]
            onRunningChanged: {
                panelContent.copilotLoading = running
                if (!running) panelContent.copilotLastFetch = Date.now()
            }
            stdout: SplitParser {
                onRead: (line) => {
                    var m = line.match(/([\d.]+)\s+([\d.]+)\s+([\d-]+)/)
                    if (m) {
                        panelContent.copilotPremiumRemaining = parseFloat(m[1])
                        panelContent.copilotPremiumTotal     = parseFloat(m[2])
                        panelContent.copilotResetDate        = m[3]
                    }
                }
            }
        }

        Process {
            id: claudeUsageFetcher
            command: ["bash", "-c",
                "TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' \"$HOME/.claude/.credentials.json\"); " +
                "curl -s -H \"Authorization: Bearer $TOKEN\" -H \"anthropic-beta: oauth-2025-04-20\" " +
                "https://api.anthropic.com/api/oauth/usage"
            ]
            onRunningChanged: {
                panelContent.claudeLoading = running
                if (!running) panelContent.claudeLastFetch = Date.now()
            }
            stdout: SplitParser {
                onRead: (line) => {
                    var m5 = line.match(/"five_hour":\{"utilization":([\d.]+),"resets_at":"([^"]+)"/)
                    var m7 = line.match(/"seven_day":\{"utilization":([\d.]+),"resets_at":"([^"]+)"/)
                    var mx = line.match(/"extra_usage":\{.*?"utilization":([\d.]+)/)
                    if (m5) { panelContent.claudeFiveHour = parseFloat(m5[1]); panelContent.claudeFiveHourResetsAt = m5[2] }
                    if (m7) { panelContent.claudeSevenDay = parseFloat(m7[1]); panelContent.claudeSevenDayResetsAt = m7[2] }
                    if (mx) panelContent.claudeCredits  = parseFloat(mx[1])
                }
            }
        }

        Timer {
            interval: 300000
            running: root.isActive
            repeat:  true
            triggeredOnStart: false
            onTriggered: {
                claudeUsageFetcher.running = false; claudeUsageFetcher.running = true
                copilotUsageFetcher.running = false; copilotUsageFetcher.running = true
            }
        }

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: 12
            spacing: 8

            // ── Header: title + clear all ─────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: panelContent.activeTab === 0 ? "Notifications"
                        : panelContent.activeTab === 1 ? "Caffeine"
                        : panelContent.activeTab === 2 ? "Calendar"
                        : "Settings"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.weight:    Font.DemiBold
                    color: Theme.fg
                    Layout.fillWidth: true
                }

                // Clear all (only on notifications tab)
                Rectangle {
                    visible: panelContent.activeTab === 0 && NotifService.historyModel.count > 0
                    implicitWidth:  clearLabel.implicitWidth + 12
                    implicitHeight: 22
                    radius: Theme.pillRadius
                    color:  clearMouse.containsMouse ? Theme.bgHover : Qt.rgba(1,1,1,0.06)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text:  "Clear all"
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        color: clearMouse.containsMouse ? Theme.accent : Theme.fgDim
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    NotifService.clearAll()
                    }
                }
            }

            // ── Media player ──────────────────────────────────────────────
            MediaPlayerWidget {
                id: mediaWidget
                Layout.fillWidth: true
            }

            Rectangle {
                visible: mediaWidget.visible
                Layout.fillWidth: true
                height: 1
                color:  Qt.rgba(0.70, 0.62, 0.86, 0.10)
            }

            // ── DND row ───────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text:  ""   // Material Symbols: bedtime
                    font.family:    Theme.iconFamily
                    font.pixelSize: Theme.iconSize - 1
                    color: NotifService.dnd ? Theme.accent : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Text {
                    text:  "Do not disturb"
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                    Layout.fillWidth: true
                }

                // Toggle switch
                Rectangle {
                    id: dndSwitch
                    width:  44
                    height: 24
                    radius: 12
                    color:  NotifService.dnd ? Theme.accent : Qt.rgba(0.30, 0.28, 0.45, 0.70)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width:  20
                        height: 20
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        x: NotifService.dnd ? parent.width - width - 2 : 2
                        color: "white"
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    NotifService.dnd = !NotifService.dnd
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color:  Qt.rgba(0.70, 0.62, 0.86, 0.15)
            }

            // ── Tab content area ──────────────────────────────────────────
            Item {
                Layout.fillWidth:  true
                Layout.fillHeight: true

                // Tab 0: Notifications
                Item {
                    anchors.fill: parent
                    visible: panelContent.activeTab === 0

                    Text {
                        visible: NotifService.historyModel.count === 0
                        anchors.centerIn: parent
                        text:    "No notifications"
                        font.family:    Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color:  Theme.fgDim
                    }

                    ScrollView {
                        anchors.fill: parent
                        visible: NotifService.historyModel.count > 0
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.vertical.policy:   ScrollBar.AsNeeded
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        Column {
                            width:   parent.width
                            spacing: 8

                            Repeater {
                                model: NotifService.appGroupsModel

                                delegate: NotifAppGroup {
                                    required property var model

                                    width:       parent.width
                                    appName:     model.appName
                                    appIcon:     model.appIcon
                                    count:       model.count
                                    unreadCount: model.unreadCount
                                    collapsed:   model.collapsed

                                    onToggleCollapse: NotifService.toggleAppCollapsed(model.appName)
                                    onClearRequested: NotifService.clearApp(model.appName)
                                }
                            }
                        }
                    }
                }

                // Tab 1: Caffeine
                Item {
                    anchors.fill: parent
                    visible: panelContent.activeTab === 1

                    ColumnLayout {
                        anchors {
                            top:   parent.top
                            left:  parent.left
                            right: parent.right
                        }
                        spacing: 16

                        // Status
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: CaffeineState.active
                                  ? (CaffeineState.durationMinutes < 0
                                     ? "Preventing sleep indefinitely"
                                     : "Preventing sleep\n" + CaffeineState.remainingLabel + " remaining")
                                  : "Screen sleep allowed"
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            color: CaffeineState.active ? Theme.accent : Theme.fgDim
                            wrapMode: Text.WordWrap
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }

                        // Mode buttons grid
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            rowSpacing:    6
                            columnSpacing: 6

                            CaffeinePill { label: "Off";  isActive: !CaffeineState.active;                                     onActivated: CaffeineState.deactivate() }
                            CaffeinePill { label: "∞";    isActive: CaffeineState.active && CaffeineState.durationMinutes < 0; onActivated: CaffeineState.activateIndefinite() }
                            CaffeinePill {
                                label:    CaffeineState.active && CaffeineState.durationMinutes === 30 ? CaffeineState.remainingLabel : "30 min"
                                isActive: CaffeineState.active && CaffeineState.durationMinutes === 30
                                onActivated: CaffeineState.activateFor(30)
                            }
                            CaffeinePill {
                                label:    CaffeineState.active && CaffeineState.durationMinutes === 60 ? CaffeineState.remainingLabel : "1 hour"
                                isActive: CaffeineState.active && CaffeineState.durationMinutes === 60
                                onActivated: CaffeineState.activateFor(60)
                            }
                            CaffeinePill {
                                label:    CaffeineState.active && CaffeineState.durationMinutes === 120 ? CaffeineState.remainingLabel : "2 hours"
                                isActive: CaffeineState.active && CaffeineState.durationMinutes === 120
                                onActivated: CaffeineState.activateFor(120)
                            }
                        }
                    }
                }

                // Tab 2: Calendar
                Item {
                    anchors.fill: parent
                    visible: panelContent.activeTab === 2

                    CalendarView {
                        anchors {
                            top:   parent.top
                            left:  parent.left
                            right: parent.right
                        }
                    }
                }

                // Tab 3: Settings
                Item {
                    anchors.fill: parent
                    visible: panelContent.activeTab === 3

                    onVisibleChanged: {
                        if (visible) {
                            wallpaperCurrentReader.running = false
                            wallpaperCurrentReader.running = true
                            if (panelContent.wallpaperModel.count === 0) {
                                wallpaperLister.running = false
                                wallpaperLister.running = true
                            }
                        }
                    }

                    // ── Top: volume + brightness ──────────────────────────
                    ColumnLayout {
                        id: settingsTop
                        anchors {
                            top:   parent.top
                            left:  parent.left
                            right: parent.right
                        }
                        spacing: 10

                        // Volume label row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: panelContent.settingsMuted || panelContent.settingsVolume === 0
                                      ? ""
                                      : panelContent.settingsVolume < 30 ? ""
                                      : panelContent.settingsVolume < 70 ? ""
                                      : ""
                                font.family:    Theme.iconFamily
                                font.pixelSize: Theme.iconSize
                                color: panelContent.settingsMuted ? Theme.fgDim : Theme.fg
                            }

                            Text {
                                text: "Volume"
                                font.family:    Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                color: Theme.fg
                                Layout.fillWidth: true
                            }

                            Text {
                                text: panelContent.settingsMuted ? "mute" : panelContent.settingsVolume + "%"
                                font.family:    Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                color: Theme.fgDim
                            }
                        }

                        SettingsSlider {
                            Layout.fillWidth: true
                            value: panelContent.settingsVolume
                            onMoved: (v) => {
                                panelContent.settingsVolume    = v
                                volumeSetSettings.command      = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v + "%"]
                                volumeSetSettings.running      = false
                                volumeSetSettings.running      = true
                            }
                        }

                        // Brightness label row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: panelContent.settingsBrightness < 25 ? ""
                                    : panelContent.settingsBrightness < 60 ? ""
                                    : ""
                                font.family:    Theme.iconFamily
                                font.pixelSize: Theme.iconSize
                                color: Theme.fg
                            }

                            Text {
                                text: "Brightness"
                                font.family:    Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                color: Theme.fg
                                Layout.fillWidth: true
                            }

                            Text {
                                text: Math.round(panelContent.settingsBrightness) + "%"
                                font.family:    Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                color: Theme.fgDim
                            }
                        }

                        SettingsSlider {
                            Layout.fillWidth: true
                            value:    panelContent.settingsBrightness
                            minValue: 5
                            onMoved: (v) => {
                                panelContent.settingsBrightness    = v
                                brightSetSettings.command          = ["brightnessctl", "set", v + "%"]
                                brightSetSettings.running          = false
                                brightSetSettings.running          = true
                            }
                        }
                    }

                    // ── Middle: wallpaper grid ────────────────────────────
                    Item {
                        anchors {
                            top:          settingsTop.bottom
                            bottom:       settingsBottom.top
                            left:         parent.left
                            right:        parent.right
                            topMargin:    10
                            bottomMargin: 10
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: ""
                                    font.family:    Theme.iconFamily
                                    font.pixelSize: Theme.iconSize
                                    color: Theme.fg
                                }
                                Text {
                                    text: "Wallpaper"
                                    font.family:    Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                            }

                            GridView {
                                id: wallpaperGrid
                                Layout.fillWidth:  true
                                Layout.fillHeight: true
                                clip: true
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                property real thumbW: Math.floor(width / 3) - 4
                                property real thumbH: Math.round(thumbW * 9 / 16)

                                cellWidth:  Math.floor(width / 3)
                                cellHeight: Math.round(Math.floor(width / 3) * 9 / 16) + 4

                                model: panelContent.wallpaperModel

                                delegate: Item {
                                    required property var model
                                    required property int index

                                    width:  wallpaperGrid.cellWidth
                                    height: wallpaperGrid.cellHeight

                                    Rectangle {
                                        property bool isCurrent: model.path === panelContent.currentWallpaper

                                        anchors.fill:    parent
                                        anchors.margins: 2
                                        radius: Theme.pillRadius
                                        clip:   true
                                        border.color: isCurrent ? Theme.accent : "transparent"
                                        border.width: isCurrent ? 2 : 0

                                        Image {
                                            anchors.fill:    parent
                                            anchors.margins: parent.isCurrent ? 2 : 0
                                            source:          "file://" + model.path
                                            sourceSize:      Qt.size(wallpaperGrid.thumbW, wallpaperGrid.thumbH)
                                            fillMode:        Image.PreserveAspectCrop
                                            asynchronous:    true
                                            smooth:          true
                                            mipmap:          true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape:  Qt.PointingHandCursor
                                            onClicked: {
                                                var p = model.path
                                                panelContent.currentWallpaper = p
                                                wallpaperApplier.command = [
                                                    "sh", "-c",
                                                    "exec \"$HOME/.local/bin/set-wallpaper\" \"$1\"",
                                                    "sh", p
                                                ]
                                                wallpaperApplier.running = false
                                                wallpaperApplier.running = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Bottom: power buttons ─────────────────────────────
                    ColumnLayout {
                        id: settingsBottom
                        anchors {
                            bottom: parent.bottom
                            left:   parent.left
                            right:  parent.right
                        }
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color:  Qt.rgba(0.70, 0.62, 0.86, 0.15)
                        }

                        GridLayout {
                            width:         parent.width
                            columns:       2
                            rowSpacing:    6
                            columnSpacing: 6

                            PowerButton {
                                icon:      ""
                                label:     "Lock"
                                iconColor: Theme.fg
                                command:   ["hyprlock"]
                                Layout.fillWidth: true
                            }
                            PowerButton {
                                icon:      ""
                                label:     "Log out"
                                iconColor: Theme.fg
                                command:   ["bash", "-c", "loginctl terminate-user $USER"]
                                Layout.fillWidth: true
                            }
                            PowerButton {
                                icon:      ""
                                label:     "Reboot"
                                iconColor: Theme.yellow
                                command:   ["systemctl", "reboot"]
                                Layout.fillWidth: true
                            }
                            PowerButton {
                                icon:      ""
                                label:     "Shut down"
                                iconColor: Theme.red
                                command:   ["systemctl", "poweroff"]
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // ── AI Usage ──────────────────────────────────────────────────
            Rectangle {
                id: aiUsageWidget
                property int aiTab: 0   // 0=Claude, 1=Copilot

                Layout.fillWidth: true
                implicitHeight:   aiUsageInner.implicitHeight + 16
                radius: Theme.pillRadius
                color:  "#262625"
                border.color: aiTab === 0 ? Theme.claude : Theme.copilot
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                ColumnLayout {
                    id: aiUsageInner
                    anchors.left:        parent.left
                    anchors.right:       parent.right
                    anchors.top:         parent.top
                    anchors.leftMargin:  12
                    anchors.rightMargin: 12
                    anchors.topMargin:   8
                    spacing: 6

                    // ── Provider tab selector ─────────────────────────────
                    RowLayout {
                        spacing: 4

                        Rectangle {
                            property bool _active: aiUsageWidget.aiTab === 0
                            implicitHeight: 26
                            implicitWidth:  tabClaudeRow.implicitWidth + 16
                            radius: 13
                            color: _active ? Qt.rgba(0.80, 0.47, 0.36, 0.18) : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                id: tabClaudeRow
                                anchors.centerIn: parent
                                spacing: 5

                                Image {
                                    source: "../assets/claudecode-color.svg"
                                    width: 14; height: 14
                                    sourceSize: Qt.size(14, 14)
                                }
                                Text {
                                    text: "Claude"
                                    font.family:    Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                    font.weight:    Font.Medium
                                    color: aiUsageWidget.aiTab === 0 ? "white" : Theme.fgDim
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: aiUsageWidget.aiTab = 0
                            }
                        }

                        Rectangle {
                            property bool _active: aiUsageWidget.aiTab === 1
                            implicitHeight: 26
                            implicitWidth:  tabCopilotRow.implicitWidth + 16
                            radius: 13
                            color: _active ? Qt.rgba(0.949, 0.961, 0.953, 0.18) : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                id: tabCopilotRow
                                anchors.centerIn: parent
                                spacing: 5

                                Image {
                                    source: "../assets/githubcopilot-color.svg"
                                    width: 14; height: 14
                                    sourceSize: Qt.size(14, 14)
                                }
                                Text {
                                    text: "Copilot"
                                    font.family:    Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                    font.weight:    Font.Medium
                                    color: aiUsageWidget.aiTab === 1 ? Theme.copilot : Theme.fgDim
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: aiUsageWidget.aiTab = 1
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    // ── Claude content ────────────────────────────────────
                    ColumnLayout {
                        visible: aiUsageWidget.aiTab === 0
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Image {
                                source: "../assets/claudecode-color.svg"
                                width:  22
                                height: 22
                                sourceSize: Qt.size(22, 22)
                            }
                            Text {
                                text: "Claude Code"
                                font.family:    Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                                font.weight:    Font.DemiBold
                                color: "white"
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: panelContent.claudeLoading
                                text: ""
                                font.family:    Theme.iconFamily
                                font.pixelSize: Theme.fontSize
                                color: Qt.rgba(1, 1, 1, 0.60)
                                RotationAnimator on rotation {
                                    running: panelContent.claudeLoading
                                    from: 0; to: 360; duration: 1000
                                    loops: Animation.Infinite
                                }
                            }
                        }

                        ClaudeBar { label: "5h";      value: panelContent.claudeFiveHour }
                        ClaudeBar { label: "7d";      value: panelContent.claudeSevenDay }
                        ClaudeBar { label: "credits"; value: panelContent.claudeCredits }

                        Text {
                            visible: panelContent.claudeFiveHourResetsAt !== "" || panelContent.claudeSevenDayResetsAt !== ""
                            text: {
                                function fmtTime(iso) {
                                    if (!iso) return ""
                                    var d = new Date(iso)
                                    return d.toLocaleTimeString([], {hour: "2-digit", minute: "2-digit"})
                                }
                                function fmtDayTime(iso) {
                                    if (!iso) return ""
                                    var d = new Date(iso)
                                    return d.toLocaleDateString([], {weekday: "short"}) + " " + d.toLocaleTimeString([], {hour: "2-digit", minute: "2-digit"})
                                }
                                var parts = []
                                if (panelContent.claudeFiveHourResetsAt !== "") parts.push("5h resets " + fmtTime(panelContent.claudeFiveHourResetsAt))
                                if (panelContent.claudeSevenDayResetsAt  !== "") parts.push("7d resets " + fmtDayTime(panelContent.claudeSevenDayResetsAt))
                                return parts.join(" · ")
                            }
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            color: Theme.fgDim
                            Layout.fillWidth: true
                        }
                    }

                    // ── Copilot content ───────────────────────────────────
                    ColumnLayout {
                        visible: aiUsageWidget.aiTab === 1
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Image {
                                source: "../assets/githubcopilot-color.svg"
                                width:  22
                                height: 22
                                sourceSize: Qt.size(22, 22)
                            }
                            Text {
                                text: "GitHub Copilot"
                                font.family:    Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                                font.weight:    Font.DemiBold
                                color: "white"
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: panelContent.copilotLoading
                                text: ""
                                font.family:    Theme.iconFamily
                                font.pixelSize: Theme.fontSize
                                color: Qt.rgba(1, 1, 1, 0.60)
                                RotationAnimator on rotation {
                                    running: panelContent.copilotLoading
                                    from: 0; to: 360; duration: 1000
                                    loops: Animation.Infinite
                                }
                            }
                        }

                        ClaudeBar {
                            label: "premium"
                            value: panelContent.copilotPremiumTotal > 0
                                   ? (1 - panelContent.copilotPremiumRemaining / panelContent.copilotPremiumTotal) * 100
                                   : 0
                            fillColor: Theme.copilot
                        }

                        Text {
                            text: {
                                var rem   = Math.round(panelContent.copilotPremiumRemaining)
                                var total = Math.round(panelContent.copilotPremiumTotal)
                                var extra = ""
                                if (panelContent.copilotResetDate !== "") {
                                    var parts = panelContent.copilotResetDate.split("-")
                                    var monthNames = ["Jan","Feb","Mar","Apr","May","Jun",
                                                      "Jul","Aug","Sep","Oct","Nov","Dec"]
                                    extra = " · resets " + monthNames[parseInt(parts[1]) - 1] + " " + parseInt(parts[2])
                                }
                                return rem + " of " + total + " remaining" + extra
                            }
                            font.family:    Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            color: Theme.fgDim
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // ── Bottom tab bar ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color:  Qt.rgba(0.70, 0.62, 0.86, 0.15)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                TabButton {
                    icon:      ""    // notifications
                    tabIndex:  0
                    activeTab: panelContent.activeTab
                    onSelect:  panelContent.activeTab = 0
                }
                TabButton {
                    icon:      ""    // coffee
                    tabIndex:  1
                    activeTab: panelContent.activeTab
                    onSelect:  panelContent.activeTab = 1
                }
                TabButton {
                    icon:      ""    // calendar_month
                    tabIndex:  2
                    activeTab: panelContent.activeTab
                    onSelect:  panelContent.activeTab = 2
                }
                TabButton {
                    icon:      ""    // tune
                    tabIndex:  3
                    activeTab: panelContent.activeTab
                    onSelect:  panelContent.activeTab = 3
                }
            }
        }
    }

    // ── Helper components ─────────────────────────────────────────────────
    component ClaudeBar: Item {
        property string label:     ""
        property real   value:     0
        property color  fillColor: Theme.claude

        Layout.fillWidth: true
        implicitHeight: barRow.implicitHeight

        RowLayout {
            id: barRow
            anchors.left:  parent.left
            anchors.right: parent.right
            spacing: 6

            Text {
                text: label
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                color: Qt.rgba(1, 1, 1, 0.70)
                Layout.preferredWidth: 44
            }

            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color:  Qt.rgba(1, 1, 1, 0.25)

                Rectangle {
                    width:  Math.max(parent.radius * 2, (value / 100) * parent.width)
                    height: parent.height
                    radius: parent.radius
                    color:  fillColor
                    Behavior on width { NumberAnimation { duration: 400 } }
                }
            }

            Text {
                text: Math.round(value) + "%"
                font.family:    Theme.monoFamily
                font.pixelSize: Theme.fontSize - 2
                color: "white"
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    component CaffeinePill: Rectangle {
        property string label
        property bool   isActive: false
        signal activated

        Layout.fillWidth: true
        implicitHeight: 36
        radius: Theme.pillRadius
        color:  _pm.containsMouse
                ? (isActive ? Qt.rgba(0.50, 0.35, 0.80, 0.80) : Theme.bgHover)
                : isActive
                  ? Qt.rgba(0.70, 0.62, 0.86, 0.28)
                  : Qt.rgba(1, 1, 1, 0.06)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors.centerIn: parent
            text:  label
            font.family:    Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            color: isActive ? Theme.accent : Theme.fgDim
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        MouseArea {
            id: _pm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked:    activated()
        }
    }

    component TabButton: Rectangle {
        property string icon
        property int    tabIndex
        property int    activeTab
        signal select

        readonly property bool _active: tabIndex === activeTab

        implicitWidth:  48
        implicitHeight: 36
        radius: Theme.pillRadius
        color:  _tbm.containsMouse
                ? Theme.bgHover
                : _active ? Qt.rgba(0.70, 0.62, 0.86, 0.14) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text:  icon
                font.family:    Theme.iconFamily
                font.pixelSize: Theme.iconSize + 2
                color: _active ? Theme.accent : Theme.fgDim
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // Active indicator dot
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width:  4; height: 4
                radius: 2
                color:  Theme.accent
                visible: _active
            }
        }

        MouseArea {
            id: _tbm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked:    parent.select()
        }
    }

    component SettingsSlider: Item {
        id: sliderRoot
        property real value:    50
        property real minValue: 0
        signal moved(real newValue)

        implicitHeight: 20

        Rectangle {
            id: sliderTrack
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:  parent.left
            anchors.right: parent.right
            height: 4
            radius: 2
            color: Qt.rgba(0.30, 0.28, 0.45, 0.70)

            Rectangle {
                width:  Math.max(sliderTrack.radius * 2,
                                 (sliderRoot.value / 100) * sliderTrack.width)
                height: parent.height
                radius: parent.radius
                color:  Theme.accent
            }
        }

        Rectangle {
            id: sliderThumb
            width:  14
            height: 14
            radius: 7
            color:  "white"
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(
                   (sliderRoot.value / 100) * (sliderRoot.width - width),
                   sliderRoot.width - width))
        }

        MouseArea {
            id: sliderMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.SizeHorCursor

            function valueFromX(mx) {
                var pct = Math.max(0, Math.min(mx, width)) / width * 100
                return Math.max(sliderRoot.minValue, Math.min(100, Math.round(pct)))
            }

            onPressed:         (mouse) => sliderRoot.moved(valueFromX(mouse.x))
            onPositionChanged: (mouse) => { if (pressed) sliderRoot.moved(valueFromX(mouse.x)) }
        }
    }
}
