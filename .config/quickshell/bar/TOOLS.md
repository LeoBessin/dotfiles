# Available Tools

A reference of all CLI tools available in this environment, installed via `installer.sh`.
Each harness can rely on these being present after installation.

---

## System / WM

| Tool | Package | Description |
|------|---------|-------------|
| `hyprland` | `hyprland` | Wayland compositor — the host WM for the bar |

---

## Qt / QuickShell Runtime

| Tool / Library | Package | Description |
|---------------|---------|-------------|
| Qt6 Base | `qt6-base` | Core Qt6 libraries |
| Qt6 Declarative | `qt6-declarative` | QML engine |
| Qt6 Wayland | `qt6-wayland` | Wayland platform plugin for Qt6 |
| Qt6 5Compat | `qt6-5compat` | Qt5 compatibility layer |
| Qt6 Multimedia | `qt6-multimedia` | Audio/video support |
| Qt6 Shader Tools | `qt6-shadertools` | Shader compilation utilities |
| Qt6 SVG | `qt6-svg` | SVG rendering |
| Qt6 Quick Timeline | `qt6-quicktimeline` | QML animation timeline |
| `quickshell` | `quickshell` *(AUR)* | Shell toolkit built on QtQuick/QML |

---

## Networking

| Tool | Package | Description |
|------|---------|-------------|
| `nmcli` / `nmtui` | `networkmanager` | Network management — query connections, Wi-Fi, VPN |

---

## Bluetooth

| Tool | Package | Description |
|------|---------|-------------|
| `bluetoothctl` | `bluez` + `bluez-utils` | Bluetooth control — list, connect, disconnect devices |

---

## Clipboard

| Tool | Package | Description |
|------|---------|-------------|
| `cliphist` | `cliphist` | Clipboard history manager — store and recall clipboard entries |

---

## Media

| Tool | Package | Description |
|------|---------|-------------|
| `playerctl` | `playerctl` | MPRIS media player control — play/pause/next/prev/metadata |
| `convert` / `magick` | `imagemagick` | Image processing — resize, crop, color extraction |

---

## Theming

| Tool | Package | Description |
|------|---------|-------------|
| `matugen` | `matugen` | Material You color scheme generator from a wallpaper |

---

## Brightness

| Tool | Package | Description |
|------|---------|-------------|
| `brightnessctl` | `brightnessctl` | Backlight and LED brightness control |

---

## Utilities

| Tool | Package | Description |
|------|---------|-------------|
| `jq` | `jq` | JSON parsing and transformation in shell scripts |
| `starship` | `starship` | Cross-shell prompt (available if a terminal module is included) |
| `fish` | `fish` | Fish shell (can be used for shell widgets or scripts) |

---

## Fonts

| Font | Package | Usage |
|------|---------|-------|
| Material Symbols (variable) | `ttf-material-symbols-variable-git` | Icon font for UI glyphs |
| Twemoji | `ttf-twemoji` | Emoji rendering |
| Cascadia Code Nerd Font | `ttf-cascadia-code-nerd` | Monospace / terminal font |
| Inter | `inter-font` | UI sans-serif font |
| JetBrains Mono | `ttf-jetbrains-mono` | Monospace fallback |
