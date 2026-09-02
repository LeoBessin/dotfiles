// Lock screen visuals — one instance per connected screen.
//
// Two pages ride one carousel:
//
//   0. shade — clock, date, weather and calendar over a SHARP wallpaper.
//              This is the glance-at-the-time page.
//   1. auth  — the password / howdy card over a BLURRED wallpaper, so the blur
//              pulls focus onto the form.
//
// The carousel is a single container of double height translated up by exactly
// one screen height, so the shade leaves the top as the auth page arrives from
// the bottom in one motion. `progress` (0..1) drives the slide, the blur
// cross-fade and the scrim together, so those three can never drift apart.
//
// Purely presentational: it owns no auth state, and not even `revealed` — the
// shared buffer, the PAM conversation and the page every monitor is on all live
// in shell.qml, so all surfaces show identical state and typing works no matter
// which one the compositor focused.
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
    // false = shade page, true = auth page. Owned by shell.qml so every monitor
    // moves together.
    property bool   revealed: false

    // ── Outputs ──────────────────────────────────────────────────────────
    signal typed(string ch)
    signal backspacePressed()
    signal clearPressed()
    signal submitPressed()
    signal capsDetected(bool on)
    signal revealRequested()
    signal shadeRequested()

    focus: true

    // The one number the whole transition hangs off.
    property real progress: revealed ? 1 : 0
    Behavior on progress {
        NumberAnimation {
            duration:    Theme.lockRevealMs
            easing.type: Theme.lockRevealEasing
        }
    }

    // ── Background ───────────────────────────────────────────────────────
    // Fixed — the wallpaper does not travel with the carousel. Sharp copy
    // underneath, blurred copy on top, cross-faded by `progress`.
    Image {
        id: wall
        anchors.fill: parent
        source: root.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: Theme.lockWallBlur
        blurMax: Theme.lockWallBlurMax
        opacity: root.progress
        // At zero opacity the blur shader is not worth running, and the shade
        // page is the common case — most locks are a glance at the clock.
        visible: opacity > 0.01 && wall.status === Image.Ready
    }

    // Fallback if the wallpaper is missing or still loading — never leave the
    // surface transparent, or the compositor shows whatever was underneath.
    Rectangle {
        anchors.fill: parent
        color: Theme.bgSolid
        visible: wall.status !== Image.Ready
    }

    // Heavier over the sharp shade, lighter over the already-softened blur.
    Rectangle {
        anchors.fill: parent
        color: root.revealed ? Theme.lockDimBlurred : Theme.lockDim
        Behavior on color { ColorAnimation { duration: Theme.lockRevealMs } }
    }

    // ── Clock source ─────────────────────────────────────────────────────
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

    // CalendarView samples `today` once at creation, so on a surface that can
    // stay up for days the highlight would never roll over. Re-feed it, but only
    // when the date actually changes — reassigning every second would rebuild
    // the whole grid 86400 times a day.
    readonly property string dayKey: Qt.formatDate(clock.now, "yyyyMMdd")
    onDayKeyChanged: if (cal) cal.today = new Date()

    // ── Carousel ─────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        // Clip the foreground only. The background MultiEffect pads its own
        // bounds outward so the blur is not cut off at the screen edge, and it
        // must not be caught by this.
        clip: true

        Item {
            width: parent.width
            height: parent.height * 2
            y: -root.progress * root.height

            // ── Page 0: shade ────────────────────────────────────────────
            Item {
                id: shadePage
                width: parent.width
                height: root.height

                // Click anywhere to open the auth page. Declared first so it
                // sits below the widgets: the calendar's month chevrons and the
                // weather card's refresh header keep their own clicks, and only
                // what they do not take reaches this.
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.revealRequested()
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.lockWidgetTopGap

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        // No card behind any of this, so each block carries its
                        // own separation from the wallpaper.
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled:        true
                            shadowColor:          Theme.lockShadowColor
                            shadowBlur:           Theme.lockShadowBlur
                            shadowVerticalOffset: Theme.lockShadowOffset
                            blurMax:              Theme.lockShadowOffset * 8
                        }

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

                    // Weather and calendar, both stripped of card and outline so
                    // they read as content laid on the wallpaper rather than as
                    // panels. Tops aligned; each keeps its own height.
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.lockWidgetGap

                        WeatherWidget {
                            width: Theme.lockWidgetColWidth
                            cardColor:    "transparent"
                            borderColor:  "transparent"
                            // The band rules are internal structure, not chrome.
                            dividerColor: Theme.lockWidgetDivider

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled:        true
                                shadowColor:          Theme.lockShadowColor
                                shadowBlur:           Theme.lockShadowBlur
                                shadowVerticalOffset: Theme.lockShadowOffset
                                blurMax:              Theme.lockShadowOffset * 8
                            }
                        }

                        CalendarView {
                            id: cal
                            width: Theme.lockWidgetColWidth

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled:        true
                                shadowColor:          Theme.lockShadowColor
                                shadowBlur:           Theme.lockShadowBlur
                                shadowVerticalOffset: Theme.lockShadowOffset
                                blurMax:              Theme.lockShadowOffset * 8
                            }
                        }
                    }
                }
            }

            // ── Page 1: auth ─────────────────────────────────────────────
            Item {
                id: authPage
                width: parent.width
                height: root.height
                y: root.height

                // This one keeps its fill and border: the form is the thing
                // being focused on, not something laid over the view.
                Rectangle {
                    id: card
                    anchors.centerIn: parent
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

                        // Password field — masked dots, never a TextInput, so
                        // there is no per-screen focus fight on a multi-monitor
                        // lock.
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
                                : root.dotCount > 0 ? "Enter to unlock · Esc to clear"
                                : "Enter for face · Esc to go back"
                        }
                    }
                }
            }
        }
    }

    // ── Keyboard handling ────────────────────────────────────────────────
    Keys.onPressed: (event) => {
        event.accepted = true

        const chorded = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)
        const isEnter = event.key === Qt.Key_Return
                     || event.key === Qt.Key_Enter
                     || event.key === Qt.Key_KP_Enter
        const isPrintable = !chorded
                         && event.text.length > 0
                         && event.text.charCodeAt(0) >= 0x20

        // ── Shade page ────────────────────────────────────────────────────
        if (!root.revealed) {
            // Enter opens the form and stops there. It must NOT fall through to
            // submit(): an empty Enter means "try my face" on the auth page, and
            // the whole point of the two-stage design is that the camera stays
            // asleep until the user has actually asked for it.
            if (isEnter) { root.revealRequested(); return }

            // A real character opens the form and is typed into it, so the user
            // can just start typing their password from the clock page.
            // Escape, bare modifiers and media keys do neither.
            if (!isPrintable) return
            root.revealRequested()
        }

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
            // Escape clears a typed password; on an empty field it is the way
            // back to the clock page.
            if (root.dotCount > 0) root.clearPressed()
            else root.shadeRequested()
            return
        }

        // Ctrl+U / Ctrl+W clear the buffer, like a shell prompt.
        if ((event.modifiers & Qt.ControlModifier)
            && (event.key === Qt.Key_U || event.key === Qt.Key_W)) {
            root.clearPressed()
            return
        }

        // Ignore other modified chords and non-printing keys.
        if (!isPrintable) return

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
