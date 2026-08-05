// shell.qml — entry point
//@ pragma UseQApplication
// Spawns one Bar per connected screen via Variants.
import QtQuick
import Quickshell
import Quickshell.Io
import "modules"
import "modules/notifications"
import "modules/launcher"
import "modules/workspaces"
import "modules/ai"
import "modules/totp"

ShellRoot {
    FontLoader {
        source: "/usr/share/fonts/ttf-material-symbols-variable/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
    }

    // Resolve an explicit monitor name, or fall back to the focused monitor when
    // the caller passes an empty string — that way a compositor keybind never has
    // to shell out to find the focused output.
    function _withNamedOrFocusedScreen(monitorName, callback) {
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === monitorName) {
                callback(Quickshell.screens[i])
                return
            }
        }
        CompositorService.withFocusedScreen(callback)
    }

    IpcHandler {
        target: "notifications"
        function toggle(monitorName: string) {
            _withNamedOrFocusedScreen(monitorName, screen => NotifService.toggleCenter(screen))
        }
    }

    IpcHandler {
        target: "launcher"
        // Resolving the focused monitor needs compositor IPC, so this is async and
        // the overlay opens a few milliseconds after the keybind fires.
        function open(mode: string) {
            CompositorService.withFocusedScreen(screen => LauncherState.open(mode, screen))
        }
    }

    IpcHandler {
        target: "totp"
        function toggle(monitorName: string) {
            _withNamedOrFocusedScreen(monitorName, screen => TotpVaultState.togglePanel(screen))
        }
    }

    IpcHandler {
        target: "workspaces"
        function open() {
            CompositorService.withFocusedScreen(screen => WorkspaceSwitcherState.open(screen))
        }
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Variants {
        model: Quickshell.screens
        AiPanel {}
    }

    Variants {
        model: Quickshell.screens
        TotpPanel {}
    }

    Variants {
        model: Quickshell.screens
        NotificationCenter {}
    }

    Variants {
        model: Quickshell.screens
        NotificationToast {}
    }

    Variants {
        model: Quickshell.screens
        PickerOverlay {}
    }

    Variants {
        model: Quickshell.screens
        WorkspaceSwitcher {}
    }
}
