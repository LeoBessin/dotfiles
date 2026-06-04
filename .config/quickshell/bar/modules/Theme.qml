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
}
