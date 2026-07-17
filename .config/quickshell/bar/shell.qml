// shell.qml — entry point
//@ pragma UseQApplication
// Spawns one Bar per connected screen via Variants.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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

    IpcHandler {
        target: "notifications"
        function toggle(monitorName: string) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === monitorName) {
                    NotifService.toggleCenter(Quickshell.screens[i])
                    return
                }
            }
            NotifService.toggleCenter(Quickshell.screens[0])
        }
    }

    IpcHandler {
        target: "launcher"
        function open(mode: string) {
            var focusedName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === focusedName) {
                    LauncherState.open(mode, Quickshell.screens[i])
                    return
                }
            }
            LauncherState.open(mode, Quickshell.screens[0])
        }
    }

    IpcHandler {
        target: "totp"
        function toggle(monitorName: string) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === monitorName) {
                    TotpVaultState.togglePanel(Quickshell.screens[i])
                    return
                }
            }
            TotpVaultState.togglePanel(Quickshell.screens[0])
        }
    }

    IpcHandler {
        target: "workspaces"
        function open() {
            var focusedName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === focusedName) {
                    WorkspaceSwitcherState.open(Quickshell.screens[i])
                    return
                }
            }
            WorkspaceSwitcherState.open(Quickshell.screens[0])
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
