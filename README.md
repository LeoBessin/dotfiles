<div align="center">

# dotfiles

**Arch Linux · Hyprland · Catppuccin**

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat&logo=arch-linux&logoColor=white)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?style=flat&logo=hyprland&logoColor=black)](https://hyprland.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-pink.svg)](LICENSE)

</div>

---

<!-- Preview image — replace the src with your actual screenshot -->
<div align="center">
  <img src="assets/preview.png" alt="Desktop preview" width="100%"/>
</div>

<!-- Video showcase — replace the URL with your actual video link -->
> **Showcase video:** _coming soon_ <!-- https://your-video-link-here -->

---

## About

A minimal, curated set of configuration files for an Arch Linux desktop built around Hyprland. Managed via a **bare git repository** — no symlink tools, no install framework, configs live at their real paths. Only the files that matter are tracked.

---

## Tech Stack

| Role | Tool |
|---|---|
| OS | [Arch Linux](https://archlinux.org) |
| Window Manager | [Hyprland](https://hyprland.org) (Lua config) |
| Shell | [Fish](https://fishshell.com) + [Starship](https://starship.rs) |
| Terminal | [Kitty](https://sw.kovidgoyal.net/kitty) |
| Bar & Launcher | [QuickShell](https://quickshell.outfoxxed.me) (QML / TypeScript) |
| Lock Screen | [Hyprlock](https://github.com/hyprwm/hyprlock) |
| Idle Daemon | [Hypridle](https://github.com/hyprwm/hypridle) |
| Editor | [VSCode](https://code.visualstudio.com) |
| Color Scheme | Catppuccin Mocha · Rosé Pine |
| Font | JetBrainsMono Nerd Font |

---

## Features

- **Lua-modular Hyprland config** — split across focused modules: `keybindings`, `windowrules`, `animations`, `autostart`, `monitors`, `input`, `options`
- **Custom QuickShell bar** — app launcher, file finder, emoji picker, icon picker, clipboard manager, notification center, media player, system stats, wallpaper picker, AI token usage widgets (Claude Code & GitHub Copilot)
- **Wallpaper sync script** — `set-wallpaper` applies a wave transition via `swww` and propagates the wallpaper to the lock screen and SDDM login manager in one command
- **Starship prompt** — right-aligned language indicators, per-project context, supports 50+ runtimes
- **Consistent theming** — Catppuccin Mocha / Rosé Pine colors applied uniformly across all tools

---

## Installation

> **Prerequisites:** `git`, `fish`

Clone the bare repository:

```bash
git clone --bare git@github.com:LeoBessin/dotfiles.git $HOME/.dotfiles
```

Check out the files into `$HOME`:

```bash
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME checkout
```

If there are conflicts with existing files, back them up first then rerun.

Hide untracked files from status output:

```bash
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME config --local status.showUntrackedFiles no
```

Add the alias to your Fish config (already included once you check out):

```fish
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
```

From then on, use `dotfiles` like regular `git` to stage, commit and push changes.

---

## Structure

```
~
├── .config/
│   ├── hypr/               # Hyprland WM — entry point + 7 Lua modules
│   │   ├── hyprland.lua
│   │   ├── lua/            # keybindings, windowrules, animations…
│   │   ├── hyprlock.conf
│   │   └── hypridle.conf
│   ├── fish/               # Shell startup & functions
│   ├── kitty/              # Terminal — Rosé Pine theme, JetBrainsMono
│   ├── quickshell/bar/     # Custom bar (QML + TypeScript)
│   └── starship/           # Prompt configuration
└── .local/
    └── bin/                # Scripts: set-wallpaper, ai-cli-picker…
```

---

## Keybindings

> `Super` = Windows key

| Shortcut | Action |
|---|---|
| `Super + T` | Terminal (Kitty) |
| `Super + B` | Browser (Brave) |
| `Super + C` | Editor (VSCode) |
| `Super + E` | File explorer (Dolphin) |
| `Super + Q` | Close focused window |
| `Super + W` | Toggle floating |
| `Super + L` | Lock screen |
| `Super + Tab` | Workspace switcher |
| `Alt + Space` | App launcher |
| `Super + Shift + E` | File finder |
| `Super + V` | Clipboard picker |
| `Super + ,` | Emoji picker |
| `Super + .` | Icon picker |
| `Super + N` | Notification center |
| `Super + Arrows` | Focus direction |
| `Shift + F11` | Toggle fullscreen |
| `Ctrl + Alt + Delete` | Logout menu |

---

## Wallpaper

Wallpapers are applied with **[awww](https://github.com/horus645/awww)**, a Wayland wallpaper daemon that supports animated transitions. The `set-wallpaper` script wraps it to keep everything in sync with a single command:

```sh
set-wallpaper /path/to/image.jpg
```

What it does under the hood:

1. Applies the wallpaper with a **wave transition** (`awww img --transition-type wave`)
2. Persists the chosen path to `~/.local/share/wallpapers/.current`
3. Copies the image to `/var/lib/sddm-wallpaper/current.jpg` so the **SDDM login screen** matches
4. Patches `hyprlock.conf` so the **lock screen** background updates immediately — no restart needed

The wallpaper picker in the QuickShell bar calls this script internally, so you can change wallpapers from the bar without touching the terminal.

---

## License

[MIT](LICENSE)
