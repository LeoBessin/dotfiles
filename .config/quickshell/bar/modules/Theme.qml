pragma Singleton
import QtQuick

QtObject {
    // ── Palette ──────────────────────────────────────────────────────────
    readonly property color accent:       "#b39ddb"   // pale purple
    readonly property color accentDim:    "#7e57c2"   // deeper purple for active states
    readonly property color bg:           Qt.rgba(0.10, 0.10, 0.18, 0.72)
    readonly property color bgSolid:      "#1a1a2e"
    readonly property color bgHover:      Qt.rgba(0.18, 0.17, 0.30, 0.85)
    readonly property color bgPopup:      Qt.rgba(0.12, 0.11, 0.22, 0.92)
    readonly property color fg:           "#e0e0f0"
    readonly property color fgDim:        "#9090b0"
    readonly property color red:          "#ef9a9a"
    readonly property color green:        "#a5d6a7"
    readonly property color yellow:       "#fff176"

    // ── Geometry ─────────────────────────────────────────────────────────
    readonly property int barHeight:      36
    readonly property int widgetPad:      8    // horizontal padding inside each widget
    readonly property int widgetSpacing:  4    // spacing between widgets in a section
    readonly property int sectionSpacing: 6    // spacing between section groups
    readonly property int radius:         10
    readonly property int pillRadius:     6

    // ── Typography ───────────────────────────────────────────────────────
    readonly property string fontFamily:  "Inter"
    readonly property string monoFamily:  "JetBrains Mono"
    readonly property string iconFamily:  "Material Symbols Rounded"
    readonly property int    fontSize:    12
    readonly property int    iconSize:    16

    // ── Animation ────────────────────────────────────────────────────────
    readonly property int animFast:       120
    readonly property int animMed:        220
}
