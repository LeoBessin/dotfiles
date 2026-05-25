import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Mpris
import "."

Item {
    id: root

    readonly property var _players: Mpris.players.values
    readonly property MprisPlayer player: {
        if (!_players || _players.length === 0) return null
        for (var i = 0; i < _players.length; i++) {
            if (_players[i] && _players[i].isPlaying) return _players[i]
        }
        return _players[0] || null
    }

    visible: player !== null
    implicitHeight: visible ? 168 : 0
    implicitWidth:  356
    clip: true

    Timer {
        interval: 1000
        running:  root.player !== null && root.player.isPlaying
        repeat:   true
        onTriggered: { if (root.player) root.player.positionChanged() }
    }

    // ── Rounded mask (visible but covered by base Rectangle above it) ───
    Rectangle {
        id: bgMask
        anchors.fill:  parent
        radius:        Theme.radius
        layer.enabled: true
    }

    // ── Base dark background ─────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color:  "#0d0b1a"
    }

    // ── Blurred album art source (hidden — rendered via MultiEffect) ─────
    Image {
        id: bgArt
        anchors { fill: parent; margins: -24 }
        source:   root.player ? (root.player.trackArtUrl || "") : ""
        fillMode: Image.PreserveAspectCrop
        smooth:   true
        visible:  false
    }

    // ── Blurred album art with rounded clipping ───────────────────────────
    MultiEffect {
        anchors.fill:       parent
        source:             bgArt
        visible:            root.player !== null && (root.player.trackArtUrl || "") !== ""
        autoPaddingEnabled: false
        blurEnabled:        true
        blur:               1.0
        blurMax:            48
        saturation:         -0.15
        maskEnabled:        true
        maskSource:         bgMask
        maskThresholdMin:   0.5
        maskSpreadAtMin:    1.0
    }

    // ── Dark scrim over blur ─────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color:        Qt.rgba(0.05, 0.04, 0.12, 0.58)
        radius:       Theme.radius
        border.color: Qt.rgba(0.70, 0.62, 0.86, 0.30)
        border.width: 1
    }

    // ── Content ──────────────────────────────────────────────────────────
    ColumnLayout {
        anchors { fill: parent; margins: 14 }
        spacing: 10

        // Track row: thumbnail + text
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                width:  52
                height: 52
                radius: 8
                color:  Qt.rgba(0.18, 0.16, 0.30, 0.70)
                clip:   true

                Image {
                    anchors.fill: parent
                    source:   root.player ? (root.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth:   true
                    visible:  source !== ""
                }

                Text {
                    anchors.centerIn: parent
                    visible:        !root.player || !root.player.trackArtUrl || root.player.trackArtUrl === ""
                    text:           ""   // music_note
                    font.family:    Theme.iconFamily
                    font.pixelSize: 26
                    color:          Theme.fgDim
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text:           root.player ? (root.player.trackTitle || "Unknown") : ""
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight:    Font.SemiBold
                    color:          Theme.fg
                    elide:          Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text:           root.player ? (root.player.trackArtist || "") : ""
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    color:          Theme.fgDim
                    elide:          Text.ElideRight
                    Layout.fillWidth: true
                    visible:        root.player !== null && (root.player.trackArtist || "") !== ""
                }

                Text {
                    text:           root.player ? (root.player.trackAlbum || "") : ""
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    color:          Qt.rgba(0.75, 0.72, 0.90, 0.80)
                    elide:          Text.ElideRight
                    Layout.fillWidth: true
                    visible:        root.player !== null && (root.player.trackAlbum || "") !== ""
                }
            }
        }

        // Progress bar
        Rectangle {
            Layout.fillWidth: true
            height:  3
            radius:  2
            color:   Qt.rgba(1, 1, 1, 0.15)
            visible: root.player !== null && root.player.lengthSupported && root.player.length > 0

            Rectangle {
                anchors.left:   parent.left
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                radius: 2
                color:  Theme.accent
                width: {
                    if (!root.player || root.player.length <= 0) return 0
                    return Math.min(1.0, root.player.position / root.player.length) * parent.width
                }
                Behavior on width { NumberAnimation { duration: 900 } }
            }
        }

        // Controls: shuffle · prev · play/pause · next · repeat
        RowLayout {
            Layout.fillWidth:  true
            Layout.alignment:  Qt.AlignHCenter
            spacing: 4

            Item { Layout.fillWidth: true }

            // Shuffle
            Rectangle {
                implicitWidth:  32
                implicitHeight: 32
                radius: 16
                color:  shuffleMouse.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text:           ""   // shuffle
                    font.family:    Theme.iconFamily
                    font.pixelSize: 18
                    color: (root.player && root.player.shuffle)
                           ? Theme.accent
                           : (shuffleMouse.containsMouse ? "#d0c8f0" : Theme.fgDim)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                MouseArea {
                    id: shuffleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    if (root.player) root.player.shuffle = !root.player.shuffle
                }
            }

            // Previous
            Rectangle {
                implicitWidth:  36
                implicitHeight: 36
                radius: 18
                color:  prevMouse.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text:           ""   // skip_previous
                    font.family:    Theme.iconFamily
                    font.pixelSize: 22
                    color: prevMouse.containsMouse ? "#d0c8f0" : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    if (root.player) root.player.previous()
                }
            }

            // Play / Pause
            Rectangle {
                implicitWidth:  48
                implicitHeight: 48
                radius: 24
                color:  playMouse.containsMouse ? Theme.accentDim : Qt.rgba(0.70, 0.62, 0.86, 0.28)
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text:           (root.player && root.player.isPlaying) ? "" : ""   // pause / play_arrow
                    font.family:    Theme.iconFamily
                    font.pixelSize: 26
                    color:          Theme.fg
                }
                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
                }
            }

            // Next
            Rectangle {
                implicitWidth:  36
                implicitHeight: 36
                radius: 18
                color:  nextMouse.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text:           ""   // skip_next
                    font.family:    Theme.iconFamily
                    font.pixelSize: 22
                    color: nextMouse.containsMouse ? "#d0c8f0" : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    if (root.player) root.player.next()
                }
            }

            // Repeat (cycles: None → Playlist → Track → None)
            Rectangle {
                implicitWidth:  32
                implicitHeight: 32
                radius: 16
                color:  repeatMouse.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    // repeat_one when looping single track, otherwise repeat
                    text: (root.player && root.player.loopStatus === MprisLoopState.Track)
                          ? ""   // repeat_one
                          : ""   // repeat
                    font.family:    Theme.iconFamily
                    font.pixelSize: 18
                    color: (root.player && root.player.loopStatus !== MprisLoopState.None)
                           ? Theme.accent
                           : (repeatMouse.containsMouse ? "#d0c8f0" : Theme.fgDim)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                MouseArea {
                    id: repeatMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        if (!root.player) return
                        if (root.player.loopStatus === MprisLoopState.None)
                            root.player.loopStatus = MprisLoopState.Playlist
                        else if (root.player.loopStatus === MprisLoopState.Playlist)
                            root.player.loopStatus = MprisLoopState.Track
                        else
                            root.player.loopStatus = MprisLoopState.None
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
