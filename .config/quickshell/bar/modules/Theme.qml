pragma Singleton
import QtQuick

QtObject {
    // ── Palette ──────────────────────────────────────────────────────────
    readonly property color accent:       "#b39ddb"   // pale purple
    readonly property color accentDim:    "#7e57c2"   // deeper purple for active states
    readonly property color bg:           Qt.rgba(0.10, 0.10, 0.18, 0.55)
    readonly property color bgSolid:      "#1a1a2e"
    readonly property color bgHover:      Qt.rgba(1.0, 1.0, 1.0, 0.06)
    readonly property color bgPopup:      Qt.rgba(0.12, 0.11, 0.22, 0.92)
    readonly property color fg:           "#e0e0f0"
    readonly property color fgDim:        "#9090b0"
    readonly property color red:          "#ef9a9a"
    readonly property color green:        "#a5d6a7"
    readonly property color yellow:       "#fff176"
    readonly property color claude:       "#CC785C"   // Anthropic brand orange
    readonly property color copilot:      "#F2F5F3"   // Copilot white

    // ── Geometry ─────────────────────────────────────────────────────────
    readonly property int barHeight:      36
    readonly property int widgetPad:      8    // horizontal padding inside each widget
    readonly property int widgetSpacing:  4    // spacing between widgets in a section
    readonly property int sectionSpacing: 6    // spacing between section groups
    readonly property int radius:         10
    readonly property int pillRadius:     6

    // ── Typography ───────────────────────────────────────────────────────
    readonly property string fontFamily:   "Inter"
    readonly property string monoFamily:  "JetBrains Mono"
    readonly property string iconFamily:  "Material Symbols Rounded"
    readonly property string nerdFamily:  "JetBrainsMono Nerd Font"
    readonly property string emojiFamily: "Noto Color Emoji"
    readonly property int    fontSize:    12
    readonly property int    iconSize:    16

    // ── Animation ────────────────────────────────────────────────────────
    readonly property int animFast:       120
    readonly property int animMed:        220

    // ── Notification palette ──────────────────────────────────────────────
    readonly property color notifPanelBg:        Qt.rgba(0.10, 0.09, 0.15, 0.85)  // panel background
    readonly property color notifCardBg:         Qt.rgba(0.18, 0.16, 0.30, 0.80)  // unread card bg / stack shadows
    readonly property color notifReadBg:         Qt.rgba(0.10, 0.10, 0.18, 0.50)  // read card background
    readonly property color notifIconBg:         Qt.rgba(0.18, 0.16, 0.30, 0.60)  // icon box background
    readonly property color notifUnreadBorder:   Qt.rgba(0.70, 0.62, 0.86, 0.25)  // unread card / toast border
    readonly property color notifBorderDim:      Qt.rgba(0.70, 0.62, 0.86, 0.10)  // dividers, group header border
    readonly property color notifBorderMid:      Qt.rgba(0.70, 0.62, 0.86, 0.15)  // section dividers, action buttons
    readonly property color notifBorderBase:     Qt.rgba(0.70, 0.62, 0.86, 0.20)  // panel outer border
    readonly property color notifHoverBg:        Qt.rgba(0.70, 0.62, 0.86, 0.08)  // read notification border
    readonly property color notifGroupHeaderBg:  Qt.rgba(0.12, 0.11, 0.22, 0.70)  // group header background
    readonly property color notifGroupHoverBg:   Qt.rgba(0.18, 0.17, 0.30, 0.85)  // group header hover
    readonly property color notifBadgeDimBg:     Qt.rgba(0.70, 0.62, 0.86, 0.25)  // read count badge background

    // ── Notification geometry ─────────────────────────────────────────────
    readonly property int notifPanelWidth:   380
    readonly property int notifCardWidth:    360
    readonly property int notifIconBoxSize:  36   // icon/image box in notification cards

    // ── Notification timings ──────────────────────────────────────────────
    readonly property int toastDuration:     5000
    readonly property int markReadDelay:      800
    readonly property int usageCacheMs:      60000

    // ── Launcher palette (Rose Pine — matches existing rofi style) ────────
    readonly property color launcherBg:         Qt.rgba(0.102, 0.086, 0.145, 0.949)
    readonly property color launcherBgInput:    Qt.rgba(0.149, 0.137, 0.227, 0.667)
    readonly property color launcherBgSelected: Qt.rgba(0.192, 0.180, 0.271, 0.600)
    readonly property color launcherBorder:     Qt.rgba(0.70, 0.62, 0.86, 0.20)
    readonly property color launcherAccent:     "#eb6f92"
    readonly property color launcherAccentAlt:  "#c4a7e7"
    readonly property color launcherFg:         "#e0def4"
    readonly property color launcherFgDim:      "#6e6a86"

    // ── Launcher geometry ─────────────────────────────────────────────────
    readonly property int launcherWidth:  580
    readonly property int launcherHeight: 680
    readonly property int launcherRadius: 16

    // ── AI panel ──────────────────────────────────────────────────────────
    readonly property int aiPanelWidth: 420

    // ── TOTP vault panel ────────────────────────────────────────────────────
    readonly property int totpPanelWidth: 380

    // ── Lock screen ───────────────────────────────────────────────────────
    // Consumed by ~/.config/quickshell/lock (separate qs instance, reaches
    // this singleton through its `modules` symlink back to this directory).
    readonly property color lockDim:         Qt.rgba(0.04, 0.04, 0.08, 0.55)  // scrim over the blurred wallpaper
    readonly property color lockCardBg:      Qt.rgba(0.10, 0.09, 0.15, 0.72)
    readonly property color lockCardBorder:  Qt.rgba(0.70, 0.62, 0.86, 0.18)
    readonly property color lockFieldBg:     Qt.rgba(0.15, 0.14, 0.23, 0.75)
    readonly property color lockFieldBorder: Qt.rgba(0.70, 0.62, 0.86, 0.22)
    readonly property color lockDotIdle:     Qt.rgba(0.88, 0.88, 0.94, 0.45)

    // Typography matches the hyprlock config it replaced: JetBrains Mono
    // throughout (Theme.monoFamily), clock Bold, everything else Regular.
    readonly property int  lockClockWeight: Font.Bold

    readonly property int  lockClockSize:   88
    readonly property int  lockDateSize:    17
    readonly property int  lockCardWidth:   340
    readonly property int  lockCardRadius:  22
    readonly property int  lockCardPad:     22
    readonly property int  lockFieldHeight: 46
    readonly property int  lockDotSize:      9
    readonly property int  lockDotSpacing:   7
    readonly property int  lockHintSize:    12

    readonly property real lockWallBlur:    0.62   // MultiEffect blur strength (0..1)
    readonly property int  lockWallBlurMax:   56   // MultiEffect blurMax radius
    readonly property int  lockShakeMs:      420   // failed-auth shake duration
    readonly property int  lockShakeAmount:   14   // failed-auth shake travel, px

    // ── Weather widget ────────────────────────────────────────────────────
    readonly property color weatherTrackBg:  Qt.rgba(1, 1, 1, 0.12)  // daily range-bar track
    readonly property color weatherSunTint:  "#ffd27f"               // sunrise/sunset slot glyph

    // Cold → warm ramp for the daily range bars, in °C. Interpolated by
    // WeatherService.tempColor(); Fahrenheit is converted before lookup so the
    // stops stay unit-independent. Mid stops reuse the green/yellow/red hues.
    readonly property var weatherRamp: [
        { t: -10, c: "#7ec8e3" },
        { t:   0, c: "#8fd3d8" },
        { t:  10, c: "#a5d6a7" },
        { t:  18, c: "#fff176" },
        { t:  25, c: "#ffb74d" },
        { t:  32, c: "#ef9a9a" }
    ]

    readonly property int weatherTempSize:      44
    readonly property int weatherIconSize:      30
    readonly property int weatherHourIconSize:  20
    readonly property int weatherDayRowHeight:  24
    readonly property int weatherHourSlots:      6
    readonly property int weatherDailyRows:      5

    readonly property int  weatherPollMs:        900000   // 15 min — Open-Meteo's own `current` interval
    readonly property int  weatherStaleMs:       600000   // 10 min — on-open refresh threshold
    readonly property int  weatherRetryBaseMs:    30000   // first retry after a failed fetch
    readonly property int  weatherHeartbeatMs:    60000   // suspend / midnight detection tick
    readonly property int  weatherSuspendGapMs:  150000   // wall-clock gap that means "we were asleep"
    readonly property real weatherGeoTtlMs:    21600000   // 6 h — IP location re-resolve ceiling
}
