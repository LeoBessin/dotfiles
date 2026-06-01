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

### Bar widgets

<details>
<summary><strong>Left — System Stats</strong></summary>

CPU usage percentage and RAM used (in GB), read directly from `/proc/stat` and `/proc/meminfo` every 2 seconds. Values are color-coded: yellow above 50 % CPU / 65 % RAM, red above 80 % CPU / 85 % RAM. Click opens `btop` in a Kitty terminal.

</details>

<details>
<summary><strong>Left — Idle Clock</strong></summary>

Two sub-elements side by side:

- **Caffeine toggle** — coffee icon when idle is allowed, sleep icon when inhibit is active. If a timed session is running the remaining time is shown next to the icon. Click toggles indefinite sleep inhibition; duration options are managed from the notification center settings tab.
- **Clock** — displays current time as `h:mm am/pm` and date as `ddd dd MMM`, updated every minute via QuickShell's `SystemClock`.

</details>

<details>
<summary><strong>Center — Workspaces</strong></summary>

Per-monitor workspace pills sourced from Hyprland's IPC. The active workspace pill is wider (28 px, accent-colored with a dark number); inactive ones are smaller (20 px, subtle white tint). Width animates on switch. Click a pill to jump to that workspace.

</details>

<details>
<summary><strong>Center — Active Window</strong></summary>

Title of the focused window on this monitor, truncated at 48 characters with an ellipsis. Hidden when no window is active. Reads the activated toplevel from the current workspace; falls back to the last known title during brief focus gaps.

</details>

<details>
<summary><strong>Right — Updates</strong></summary>

Combined pending update count across pacman, AUR (`yay`), and Flatpak. Badge colors: green = up to date, accent = updates available, yellow = currently checking. Hover shows a tooltip with the per-source breakdown. Left-click opens a Kitty terminal running `fastfetch; yay && flatpak update`. Right-click triggers a fresh check without upgrading.

</details>

<details>
<summary><strong>Right — Brightness</strong></summary>

Screen backlight level percentage via `brightnessctl`. Icon changes across three tiers (low / medium / high). Scroll up/down to adjust ±5 %; click toggles between 30 % and 100 %. A finer slider is also available in the notification center settings tab.

</details>

<details>
<summary><strong>Right — Network</strong></summary>

Wi-Fi SSID with a four-tier signal-strength icon (≥75 % / ≥50 % / ≥25 % / below). Below the SSID, live transmit and receive speeds are shown in B/K/M per second, sourced from NetworkManager via `NetworkService`. Non-interactive.

</details>

<details>
<summary><strong>Right — Volume</strong></summary>

Default audio sink volume and mute state via `wpctl` / `pactl`. Icon adapts to level (muted / low / medium / high). Scroll to adjust volume, left-click to toggle mute, right-click to open pavucontrol on the playback tab. Reacts in real time to `pactl subscribe` events.

</details>

<details>
<summary><strong>Right — Microphone</strong></summary>

Default PipeWire source mute state. Mic icon turns red when muted; a small colored dot (green = live, red = muted) provides a quick-glance indicator. Left-click toggles mute, right-click opens pavucontrol on the recording tab.

</details>

<details>
<summary><strong>Right — Tray</strong></summary>

System tray via `Quickshell.Services.SystemTray`. Each item renders its icon. Left-click activates the item; right-click opens a custom themed popup menu. Submenus are supported — drilling into one shows a Back button to navigate up.

</details>

<details>
<summary><strong>Right — Battery</strong></summary>

Battery level and state from UPower. Icon set covers seven discharge levels plus charging variants. Color: green when charging or full, yellow at ≤ 30 %, red at ≤ 15 %. Non-interactive.

</details>

<details>
<summary><strong>Right — Notifications button</strong></summary>

Bell icon with an unread-count badge. Shows a strikethrough bell when Do Not Disturb is enabled. Badge disappears once all notifications are read. Click toggles the notification center panel.

</details>

### Notification center (`Super + N`)

A slide-in panel from the right edge, 380 px wide, with two tabs accessed from the bottom tab bar.

<details>
<summary><strong>Notifications tab — Media player</strong></summary>

MPRIS media player widget shown at the top of the panel whenever a player is active. Features:

- Album art thumbnail (52 × 52) and blurred art as the card background
- Track title, artist, and album
- Playback progress bar (1 s resolution)
- Controls: shuffle toggle, previous, play/pause, next, repeat (cycles None → Playlist → Track)

Prefers the currently playing player; falls back to the first available one.

</details>

<details>
<summary><strong>Notifications tab — Do Not Disturb</strong></summary>

A bedtime icon, "Do not disturb" label, and a toggle switch. When enabled, incoming notifications are silenced (no toasts) and the bar bell icon switches to a strikethrough variant.

</details>

<details>
<summary><strong>Notifications tab — Notification list</strong></summary>

Scrollable list of notifications grouped by application (`NotifAppGroup`). Each group can be collapsed/expanded; a per-group clear button removes all notifications from that app. A "Clear all" button appears in the header when the history is non-empty. Notifications are marked as read 800 ms after the panel opens. Shows "No notifications" when the list is empty.

</details>

<details>
<summary><strong>Notifications tab — AI usage widget</strong></summary>

A pinned card with a tab selector for two providers:

- **Claude Code** — Fetches usage from the Anthropic API (`/api/oauth/usage`) using the OAuth token from `~/.claude/.credentials.json`. Displays three progress bars: 5-hour utilization, 7-day utilization, and credits. Reset times are shown below the bars.
- **GitHub Copilot** — Fetches premium interaction quota from `api.github.com/copilot_internal/user` using the token from `~/.config/github-copilot/apps.json`. Displays a single bar (remaining / total) and the monthly reset date.

Both providers are fetched on panel open with a 60-second cache, and auto-refresh every 5 minutes while the panel stays open.

</details>

<details>
<summary><strong>Notifications tab — Calendar</strong></summary>

A compact month calendar view pinned at the bottom of the notifications tab.

</details>

<details>
<summary><strong>Settings tab — Volume & Brightness</strong></summary>

Two sliders:

- **Volume** — controls the default audio sink via `wpctl set-volume`. Shows current level or "mute"; icon adapts to level. Kept in sync with `pactl subscribe` events.
- **Brightness** — controls screen backlight via `brightnessctl set`. Minimum value is 5 % to prevent a fully black screen.

</details>

<details>
<summary><strong>Settings tab — Keyboard brightness</strong></summary>

Four pill buttons — Off / 1 / 2 / Max — that set the keyboard backlight level via `KeyboardBrightnessService`.

</details>

<details>
<summary><strong>Settings tab — Wallpaper picker</strong></summary>

A 3-column thumbnail grid (16:9 aspect ratio) browsing `~/.local/share/wallpapers/`. Subdirectories are shown as folder cards and can be drilled into; a back arrow navigates up. The currently active wallpaper is highlighted with an accent border. Clicking a thumbnail calls `set-wallpaper` to apply it immediately.

</details>

<details>
<summary><strong>Settings tab — Caffeine</strong></summary>

Sleep prevention controls backed by `CaffeineState` (uses `systemd-inhibit`). Status text at the top describes the current state. Duration pills: Off / ∞ (indefinite) / 30 min / 1 hour / 2 hours. The active pill shows the remaining time instead of its label.

</details>

<details>
<summary><strong>Settings tab — Power buttons</strong></summary>

Four buttons in a row: **Lock** (`hyprlock`), **Log out** (`loginctl terminate-user`), **Reboot** (`systemctl reboot`, requires confirmation), **Shut down** (`systemctl poweroff`, requires confirmation). Reboot and Shut down are colored yellow and red respectively to signal destructiveness.

</details>

### Launcher / pickers

A centered floating card with a proportional wallpaper header. Closed with `Escape` or a click outside.

<details>
<summary><strong>App launcher (<code>Alt + Space</code>)</strong></summary>

4-column icon grid of installed applications. Type to filter by name; arrow keys and Enter to navigate and launch. Apps are launched detached via `setsid --fork`.

</details>

<details>
<summary><strong>File finder (<code>Super + Shift + E</code>)</strong></summary>

Directory browser starting at `$HOME`. The path breadcrumb is shown in the search bar; a back arrow navigates up. Directories open in-place; files are opened with `xdg-open`.

</details>

<details>
<summary><strong>Emoji picker (<code>Super + ,</code>)</strong></summary>

Searchable list of emoji characters. Selecting one copies it to the clipboard via `wl-copy`.

</details>

<details>
<summary><strong>Icon picker (<code>Super + .</code>)</strong></summary>

Searchable list of Nerd Font glyphs rendered in the configured nerd font. Selecting one copies the character via `wl-copy`.

</details>

<details>
<summary><strong>Clipboard manager (<code>Super + V</code>)</strong></summary>

History from `cliphist`. Text entries show a preview; image entries show a 44 × 44 thumbnail. Left/right arrow keys paginate through long histories. Selecting an entry restores it to the clipboard via `cliphist decode | wl-copy`.

</details>

<details>
<summary><strong>Window switcher</strong></summary>

Lists all open windows across workspaces. Each entry shows the window title and a window-class chip. Selecting one focuses the window via a Hyprland dispatch.

</details>

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
