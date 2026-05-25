// shell.qml — entry point
//@ pragma UseQApplication
// Spawns one Bar per connected screen via Variants.
import QtQuick
import Quickshell
import "modules"

ShellRoot {
    FontLoader {
        source: "/usr/share/fonts/ttf-material-symbols-variable/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
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
}
