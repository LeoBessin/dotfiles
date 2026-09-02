// QuickShell lock screen — replaces hyprlock.
//
// Run:      qs -c lock -n          (-n: refuse to start a second lock)
// Wired to: ~/.config/hypr/hypridle.conf  ->  lock_cmd
// Reached by `loginctl lock-session` (Mod+L / Mod+Escape), which logind turns
// into a Lock signal that hypridle answers with lock_cmd.
//
// Auth runs in two stages so the camera never wakes until a password has
// actually been tried and rejected:
//
//   1. /etc/pam.d/login    — password only. howdy is not in this chain (it
//                            appears only in hyprlock, sudo and sddm), so
//                            nothing touches the camera here.
//   2. /etc/pam.d/hyprlock — started ONLY after stage 1 rejects the password.
//                            That file is `pam_howdy.so sufficient` followed by
//                            `include login`, so howdy runs first: a face match
//                            returns success with no prompt at all. If howdy
//                            fails, PAM falls through and asks for a password —
//                            at which point we abort() rather than answer,
//                            because answering would make pam_faillock count a
//                            second failure for one wrong password.
//
// Stage 2 depends on the hyprlock package, which owns that PAM file. If it is
// ever removed, face unlock stops and stage 1 keeps working on its own.
//
// Escape hatch: if this QML fails *after* the compositor grants the lock, the
// session stays locked with a blank fallback surface. Recover with Ctrl+Alt+F2
// then `loginctl unlock-session`.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "modules"

ShellRoot {
    id: root

    // ── Shared state (above the per-screen surfaces) ─────────────────────
    property string password: ""
    property string wallpaper: ""
    property bool   busy: false
    property string message: ""
    property bool   messageIsError: false
    property bool   capsOn: false
    property int    shakeTrigger: 0

    // The password typed for the attempt currently in flight. Held separately so
    // the visible buffer can be cleared without losing the in-flight value.
    property string submitted: ""

    // True when stage 2 was invoked directly by an empty Enter rather than by a
    // rejected password. Only changes the wording of a stage 2 failure.
    property bool faceOnly: false

    function submit() {
        if (busy) return
        message = ""
        messageIsError = false

        // Empty field: skip the password stage and go straight to the camera.
        if (password.length === 0) {
            busy = true
            faceOnly = true
            tryFace()
            return
        }

        busy = true
        faceOnly = false
        submitted = password

        // Stage 1: password only. No camera.
        if (!pamPassword.active) pamPassword.start()
    }

    // Stage 2: howdy. Reached either by an empty Enter or by a rejected password.
    function tryFace() {
        message = "Looking for your face…"
        messageIsError = false
        if (!pamFace.active) pamFace.start()
    }

    function fail(text) {
        busy = false
        faceOnly = false
        submitted = ""
        password = ""
        messageIsError = true
        message = text
        shakeTrigger++
    }

    function succeed() {
        busy = false
        faceOnly = false
        submitted = ""
        message = ""
        messageIsError = false
        lock.locked = false
    }

    // Stage 2 gave up. Report what the user actually attempted.
    function faceFailed() {
        fail(faceOnly ? "Face not recognised" : "Incorrect password")
    }

    // ── Lock ─────────────────────────────────────────────────────────────
    WlSessionLock {
        id: lock
        locked: true

        surface: WlSessionLockSurface {
            // Opaque base: the compositor must never see through this surface.
            color: Theme.bgSolid

            LockContent {
                anchors.fill: parent

                wallpaper: root.wallpaper
                dotCount: root.password.length
                busy: root.busy
                message: root.message
                messageIsError: root.messageIsError
                capsOn: root.capsOn
                username: Quickshell.env("USER") ?? ""
                shakeTrigger: root.shakeTrigger

                onTyped: (ch) => { if (!root.busy) root.password += ch }
                onBackspacePressed: if (!root.busy) root.password = root.password.slice(0, -1)
                onClearPressed: if (!root.busy) root.password = ""
                onSubmitPressed: root.submit()
                onCapsDetected: (on) => root.capsOn = on
            }
        }

        onLockedChanged: if (!locked) quit.start()
    }

    // Give the compositor a moment to process the unlock before the process
    // exits. Dying while still locked would leave the fallback surface up.
    Timer {
        id: quit
        interval: 400
        onTriggered: Qt.quit()
    }

    // Release the lock without authenticating:
    //
    //   qs -c lock ipc call lock unlock
    //
    // This is what hypridle's unlock_cmd calls, so `loginctl unlock-session`
    // still works. Note it must NOT be `pkill qs` — that would kill the bar too,
    // and killing a lock client without unlocking leaves the compositor's blank
    // fallback surface up.
    //
    // Any process running as this user can call this. That is the same exposure
    // the previous setup had, where `pkill hyprlock` unlocked the session — the
    // lock defends against physical access, not local code execution.
    //
    // It is also the recovery path if this UI ever wedges. From a TTY (Ctrl+Alt+F2):
    //   XDG_RUNTIME_DIR=/run/user/1000 qs -c lock ipc call lock unlock
    IpcHandler {
        target: "lock"
        function unlock(): void {
            root.message = ""
            root.busy = false
            lock.locked = false
        }
    }

    // ── Stage 1: password (no camera) ────────────────────────────────────
    PamContext {
        id: pamPassword
        configDirectory: "/etc/pam.d"
        config: "login"

        onResponseRequiredChanged: {
            if (pamPassword.responseRequired) pamPassword.respond(root.submitted)
        }

        onCompleted: (result) => {
            if (result === PamResult.Success)  { root.succeed(); return }
            if (result === PamResult.MaxTries) { root.fail("Too many attempts"); return }
            if (result === PamResult.Error)    { root.fail("Authentication error"); return }
            // Plain rejection — now, and only now, give the camera a turn.
            root.tryFace()
        }

        onError: (err) => root.fail("PAM: " + PamError.toString(err))
    }

    // ── Stage 2: howdy, only after a rejected password ───────────────────
    PamContext {
        id: pamFace
        configDirectory: "/etc/pam.d"
        config: "hyprlock"

        onResponseRequiredChanged: {
            // howdy declined and PAM has fallen through to `include login`,
            // which now wants a password. Abort rather than answer: on the
            // empty-Enter path there is no password to give, and on the
            // rejected-password path it is already known to be wrong — sending
            // it again would cost a second pam_faillock strike for one mistake.
            if (pamFace.responseRequired) {
                pamFace.abort()
                root.faceFailed()
            }
        }

        onCompleted: (result) => {
            if (result === PamResult.Success) root.succeed()
            else if (result === PamResult.MaxTries) root.fail("Too many attempts")
            else root.faceFailed()
        }

        // abort() surfaces here too; faceFailed() has already run in that case,
        // so only report if the attempt is somehow still in flight.
        onError: (err) => {
            if (root.busy) root.faceFailed()
        }
    }

    // ── Wallpaper ────────────────────────────────────────────────────────
    // No FileView in quickshell 0.3.0; same Process+SplitParser pattern the
    // bar's NotificationCenter uses to read the marker.
    Process {
        running: true
        command: ["sh", "-c", "cat \"$HOME/.local/share/wallpapers/.current\" 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: (line) => {
                const p = line.trim()
                if (p !== "") root.wallpaper = "file://" + p
            }
        }
    }
}
