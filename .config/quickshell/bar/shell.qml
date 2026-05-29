// shell.qml — entry point
//@ pragma UseQApplication
// Spawns one Bar per connected screen via Variants.
import QtQuick
import Quickshell
import Quickshell.Io
import "modules"
import "modules/notifications"
import "modules/launcher"

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
            LauncherState.open(mode, Quickshell.screens[0])
        }
    }

    Variants {
        model: Quickshell.screens
        Bar {}
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
}
