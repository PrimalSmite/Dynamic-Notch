//@ pragma UseQApplication
import Quickshell
import QtQuick

// Динамический остров для Hyprland.
// Запуск:  qs -p /путь/к/этой/папке   (или скопируй в ~/.config/quickshell)
ShellRoot {
    Variants {
        model: Quickshell.screens
        Island {}
    }
}
