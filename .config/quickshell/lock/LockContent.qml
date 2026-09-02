// Lock screen visuals — one instance per connected screen.
//
// Purely presentational: it owns no auth state. The shared buffer and PAM
// conversation live in shell.qml, so both monitors show identical state and
// typing works regardless of which surface the compositor focused.
//
// Rendered by shell.qml (real lock) and preview.qml (windowed dev harness).

import QtQuick
import QtQuick.Effects
import "modules"

Item {
    id: root

    // ── Inputs ───────────────────────────────────────────────────────────
    property string wallpaper: ""
    property int    dotCount: 0
    property bool   busy: false
    property string message: ""
    property bool   messageIsError: false
    property bool   capsOn: false
    property string username: ""
    // Bumped by shell.qml on failed auth to fire the shake animation.
    property int    shakeTrigger: 0

    // ── Outputs ──────────────────────────────────────────────────────────
    signal typed(string ch)
    signal backspacePressed()
    signal clearPressed()
    signal submitPressed()
    signal capsDetected(bool on)

    focus: true

    // ── Background: blurred wallpaper + scrim ─────────────────────────────
    Image {
        id: wall
        anchors.fill: parent
        source: root.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: Theme.lockWallBlur
        blurMax: Theme.lockWallBlurMax
        visible: wall.status === Image.Ready
    }

    // Fallback if the wallpaper is missing or still loading — never leave the
    // surface transparent, or the compositor shows whatever was underneath.
    Rectangle {
        anchors.fill: parent
        color: Theme.bgSolid
        visible: wall.status !== Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.lockDim
    }

    // ── Clock ────────────────────────────────────────────────────────────
    Column {
        id: clockBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: card.top
        anchors.bottomMargin: Theme.lockCardPad * 3
        spacing: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.now, "HH:mm")
            color: Theme.fg
            font.family: Theme.monoFamily
            font.pixelSize: Theme.lockClockSize
            font.weight: Theme.lockClockWeight
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.now, "dddd d MMMM")
            color: Theme.fgDim
            font.family: Theme.monoFamily
            font.pixelSize: Theme.lockDateSize
        }
    }

    QtObject {
        id: clock
        property date now: new Date()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.now = new Date()
    }

    // ── Auth card ────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Theme.lockClockSize / 2
        width: Theme.lockCardWidth
        implicitHeight: cardCol.implicitHeight + Theme.lockCardPad * 2
        height: implicitHeight
        radius: Theme.lockCardRadius
        color: Theme.lockCardBg
        border.width: 1
        border.color: Theme.lockCardBorder

        // Shake on failed auth.
        transform: Translate { id: shakeShift }

        SequentialAnimation {
            id: shake
            loops: 1
            NumberAnimation {
                target: shakeShift; property: "x"
                from: 0; to: Theme.lockShakeAmount
                duration: Theme.lockShakeMs / 6; easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: shakeShift; property: "x"
                to: -Theme.lockShakeAmount
                duration: Theme.lockShakeMs / 3; easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: shakeShift; property: "x"
                to: Theme.lockShakeAmount / 2
                duration: Theme.lockShakeMs / 4; easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: shakeShift; property: "x"
                to: 0
                duration: Theme.lockShakeMs / 4; easing.type: Easing.OutBack
            }
        }

        Column {
            id: cardCol
            anchors.centerIn: parent
            width: parent.width - Theme.lockCardPad * 2
            spacing: Theme.lockCardPad * 0.6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.username
                color: Theme.fg
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontSize + 2
                visible: root.username !== ""
            }

            // Password field — masked dots, never a TextInput, so there is no
            // per-screen focus fight on a multi-monitor lock.
            Rectangle {
                width: parent.width
                height: Theme.lockFieldHeight
                radius: height / 2
                color: Theme.lockFieldBg
                border.width: 1
                border.color: root.messageIsError ? Theme.red
                            : root.busy ? Theme.accent
                            : Theme.lockFieldBorder

                Behavior on border.color {
                    ColorAnimation { duration: Theme.animFast }
                }

                // Idle placeholder.
                Text {
                    anchors.centerIn: parent
                    text: "Password"
                    color: Theme.fgDim
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSize
                    visible: root.dotCount === 0 && !root.busy
                }

                // Typed characters.
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.lockDotSpacing
                    visible: root.dotCount > 0 && !root.busy

                    Repeater {
                        model: Math.min(root.dotCount, 24)
                        Rectangle {
                            width: Theme.lockDotSize
                            height: Theme.lockDotSize
                            radius: width / 2
                            color: Theme.fg
                        }
                    }
                }

                // Authenticating pulse.
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.lockDotSpacing
                    visible: root.busy

                    Repeater {
                        model: 3
                        Rectangle {
                            width: Theme.lockDotSize
                            height: Theme.lockDotSize
                            radius: width / 2
                            color: Theme.accent

                            SequentialAnimation on opacity {
                                running: root.busy
                                loops: Animation.Infinite
                                PauseAnimation { duration: index * 130 }
                                NumberAnimation { to: 0.25; duration: 320 }
                                NumberAnimation { to: 1.0;  duration: 320 }
                                PauseAnimation { duration: (2 - index) * 130 }
                            }
                        }
                    }
                }
            }

            // Status line: PAM message, caps-lock warning, or key hint.
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.family: Theme.monoFamily
                font.pixelSize: Theme.lockHintSize
                color: root.messageIsError ? Theme.red
                     : root.capsOn ? Theme.yellow
                     : Theme.fgDim
                text: root.message !== "" ? root.message
                    : root.capsOn ? "Caps Lock is on"
                    : root.busy ? "Authenticating…"
                    : root.dotCount > 0 ? "Enter to unlock"
                    : "Enter to unlock · empty Enter for face"
            }
        }
    }

    // ── Keyboard handling ────────────────────────────────────────────────
    Keys.onPressed: (event) => {
        event.accepted = true

        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_KP_Enter:
            root.submitPressed()
            return
        case Qt.Key_Backspace:
            if (event.modifiers & Qt.ControlModifier) root.clearPressed()
            else root.backspacePressed()
            return
        case Qt.Key_Escape:
            root.clearPressed()
            return
        }

        // Ctrl+U / Ctrl+W clear the buffer, like a shell prompt.
        if ((event.modifiers & Qt.ControlModifier)
            && (event.key === Qt.Key_U || event.key === Qt.Key_W)) {
            root.clearPressed()
            return
        }

        // Ignore other modified chords and non-printing keys.
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
        if (event.text.length === 0) return
        if (event.text.charCodeAt(0) < 0x20) return

        // Caps Lock has no QML modifier flag. Infer it: an unshifted letter
        // arriving uppercase (or a shifted one arriving lowercase) means it is on.
        if (/^[A-Za-z]$/.test(event.text)) {
            const shift = (event.modifiers & Qt.ShiftModifier) !== 0
            const upper = event.text === event.text.toUpperCase()
            root.capsDetected(upper !== shift)
        }

        root.typed(event.text)
    }

    onShakeTriggerChanged: if (shakeTrigger > 0) shake.restart()
}
