// shell.qml — entry point
//@ pragma UseQApplication
// Spawns one Bar per connected screen via Variants.
import QtQuick
import Quickshell
import "modules"

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }
}
