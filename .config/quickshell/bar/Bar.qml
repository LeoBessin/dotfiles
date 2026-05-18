// Bar.qml — one panel window per monitor
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "modules"
import "modules/left"
import "modules/center"
import "modules/right"

PanelWindow {
    id: root

    // Variants injects modelData (the ShellScreen); bind it to PanelWindow.screen
    property var modelData
    screen: modelData

    anchors {
        top:   true
        left:  true
        right: true
    }

    // ExclusionMode.Normal doesn't fire with 3-edge anchors; set the zone explicitly
    exclusionMode: ExclusionMode.Exclusive
    exclusiveZone: Theme.barHeight + 4

    // Layer-shell positioning
    WlrLayershell.layer:    WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitHeight: Theme.barHeight + 4  // +4 for 2px top + 2px bottom margin
    color:  "transparent"
    surfaceFormat.opaque: false

    // ── Background: blurred + translucent ────────────────────────────────
    Rectangle {
        id: barBg
        anchors.fill: parent
        anchors.margins: 2
        color:        Theme.bg
        radius:       Theme.radius
        border.color: Qt.rgba(0.70, 0.62, 0.86, 0.25)
        border.width: 1
    }

    // Background blur via attached property
    BackgroundEffect.blurRegion: Region { item: barBg }

    // ── Three-section layout ─────────────────────────────────────────────

    // LEFT — anchored to left edge
    RowLayout {
        anchors.left:        parent.left
        anchors.leftMargin:  4
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.widgetSpacing

        SystemStats {}
        IdleClock {}
    }

    // CENTER — truly centered in the bar regardless of left/right widths
    RowLayout {
        anchors.centerIn: parent
        spacing: Theme.widgetSpacing

        Workspaces   { barScreen: root.screen }
        ActiveWindow { barScreen: root.screen }
    }

    // RIGHT — anchored to right edge
    RowLayout {
        anchors.right:        parent.right
        anchors.rightMargin:  4
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.widgetSpacing

        Updates    {}
        Brightness {}
        Network    {}
        Volume     {}
        Microphone {}
        Tray       {}
        Battery    {}
        Power      {}
    }
}
