# QuickShell Bar — Project Guide

A Hyprland status bar built with [QuickShell](https://quickshell.outfoxxed.me/) (QtQuick/QML).
Entry point: `shell.qml`. The bar runs one `Bar` window, one `NotificationCenter` panel, and one `NotificationToast` overlay per connected screen.

---

## Directory Structure

```
bar/
├── shell.qml                          # Entry point — spawns windows per screen
├── Bar.qml                            # Main panel: left / center / right sections
├── assets/                            # SVG icons (Claude, Copilot)
├── modules/
│   ├── qmldir                         # Master module: singletons + shared components
│   ├── Theme.qml                      # SINGLETON — all colors, sizes, fonts, timings
│   ├── NotifService.qml               # SINGLETON — notification state machine
│   ├── CaffeineState.qml              # SINGLETON — sleep prevention state
│   ├── UpdateService.qml              # SINGLETON — system update polling
│   ├── VolumeService.qml              # SINGLETON — PipeWire volume
│   ├── BrightnessService.qml          # SINGLETON — screen backlight
│   ├── KeyboardBrightnessService.qml  # SINGLETON — keyboard backlight
│   ├── NetworkService.qml             # SINGLETON — NetworkManager state
│   ├── BarWidget.qml                  # Base component for bar pill-widgets
│   ├── CalendarView.qml               # Calendar tab component
│   ├── MediaPlayerWidget.qml          # MPRIS media player widget
│   ├── PowerButton.qml                # Reusable power action button
│   ├── notifications/
│   │   ├── qmldir                     # Notification UI components
│   │   ├── NotificationCenter.qml     # Slide-in panel (tabs: notifs, caffeine, calendar, settings)
│   │   ├── NotificationToast.qml      # Overlay window — shows up to 5 toasts
│   │   ├── NotificationItem.qml       # Single notification card (history panel)
│   │   ├── NotifAppGroup.qml          # App-grouped notification container
│   │   └── ToastCard.qml             # Temporary popup card with slide animation
│   ├── left/                          # SystemStats, IdleClock
│   ├── center/                        # Workspaces, ActiveWindow
│   └── right/                         # Battery, Brightness, Microphone, Network,
│                                      # Notifications (button), Tray, Updates, Volume
└── TOOLS.md                           # CLI tools available in this environment
```

---

## QML Module System

QuickShell uses `qmldir` files to register types per directory. Import rules:

| File location | Import to access singletons/components |
|---|---|
| `modules/*.qml` | `import "."` (already in module root) |
| `modules/notifications/*.qml` | `import ".."` (parent = module root) |
| `modules/left/*.qml` | `import ".."` |
| `modules/center/*.qml` | `import ".."` |
| `modules/right/*.qml` | `import ".."` |
| `shell.qml` / `Bar.qml` | `import "modules"` + `import "modules/notifications"` |

**Singletons** are auto-instantiated once and accessed by type name (e.g., `Theme.accent`, `NotifService.dnd`). They are registered with the `singleton` keyword in `qmldir`.

If you add a new singleton or a new `import` line to `shell.qml`, QuickShell requires a **full restart** (hot reload is not enough).

---

## Theme — Single Source of Truth

**All** colors, sizes, fonts, and durations must come from `modules/Theme.qml`. Never hardcode `Qt.rgba(...)`, pixel sizes, or millisecond values in component files.

### Palette
| Property | Value | Use |
|---|---|---|
| `Theme.accent` | `#b39ddb` | Active states, unread indicators |
| `Theme.accentDim` | `#7e57c2` | Hover on accent elements |
| `Theme.bg` | `rgba(0.10,0.10,0.18,0.55)` | Bar background (blurred) |
| `Theme.bgSolid` | `#1a1a2e` | Opaque dark background |
| `Theme.bgHover` | `rgba(1,1,1,0.06)` | Generic hover tint |
| `Theme.bgPopup` | `rgba(0.12,0.11,0.22,0.92)` | Toast/popup background |
| `Theme.fg` | `#e0e0f0` | Primary text |
| `Theme.fgDim` | `#9090b0` | Secondary/muted text |
| `Theme.red/green/yellow` | — | Status colors |
| `Theme.claude` | `#CC785C` | Anthropic brand |
| `Theme.copilot` | `#F2F5F3` | Copilot brand |

### Notification palette
| Property | Value | Use |
|---|---|---|
| `Theme.notifCardBg` | `rgba(0.18,0.16,0.30,0.80)` | Unread card background, stack shadows |
| `Theme.notifBorderDim` | `rgba(0.70,0.62,0.86,0.10)` | Dividers, group header border |
| `Theme.notifBorderMid` | `rgba(0.70,0.62,0.86,0.15)` | Section dividers, action buttons |
| `Theme.notifBorderBase` | `rgba(0.70,0.62,0.86,0.20)` | Panel outer border |
| `Theme.notifHoverBg` | `rgba(0.70,0.62,0.86,0.08)` | Read notification border |

### Geometry & Typography
| Property | Value |
|---|---|
| `Theme.barHeight` | 36px |
| `Theme.radius` | 10px (cards/panels) |
| `Theme.pillRadius` | 6px (buttons/pills) |
| `Theme.notifPanelWidth` | 380px |
| `Theme.notifCardWidth` | 360px |
| `Theme.fontFamily` | "Inter" |
| `Theme.monoFamily` | "JetBrains Mono" |
| `Theme.iconFamily` | "Material Symbols Rounded" |
| `Theme.fontSize` | 12px |
| `Theme.iconSize` | 16px |

### Animation & Timings
| Property | Value | Use |
|---|---|---|
| `Theme.animFast` | 120ms | Color/opacity transitions |
| `Theme.animMed` | 220ms | Slide/position animations |
| `Theme.toastDuration` | 5000ms | Toast auto-dismiss |
| `Theme.markReadDelay` | 800ms | Auto-read on panel open |
| `Theme.usageCacheMs` | 60000ms | Claude/Copilot usage cache TTL |

---

## Key Singletons

### `NotifService`
Central notification state machine. Consumes D-Bus notifications via `NotificationServer`.

**Public API:**
```qml
NotifService.historyModel        // ListModel — all notifications (newest first)
NotifService.appGroupsModel      // ListModel — notifications grouped by app
NotifService.unreadCount         // int
NotifService.centerOpen          // bool
NotifService.dnd                 // bool — Do Not Disturb (suppresses toasts)
NotifService.targetScreen        // screen reference

NotifService.toggleCenter(screen)
NotifService.closeCenter()
NotifService.markRead(notifId)
NotifService.markAllRead()
NotifService.closeNotification(notifId)
NotifService.clearAll()
NotifService.clearApp(appName)
NotifService.toggleAppCollapsed(appName)

signal toastRequested(var toastData)
```

### `CaffeineState`
Controls `systemd-inhibit` to prevent sleep.
```qml
CaffeineState.active             // bool
CaffeineState.durationMinutes   // int (-1 = indefinite)
CaffeineState.remainingLabel    // string
CaffeineState.activateFor(minutes)
CaffeineState.activateIndefinite()
CaffeineState.deactivate()
```

---

## Notification Flow

```
D-Bus → NotificationServer.onNotification
      → NotifService._add(notif)
      → historyModel.insert(0, …)       // newest first
      → appGroupsModel update           // group by app, bubble to top
      → if !dnd: emit toastRequested()
                 → NotificationToast window renders ToastCard
      → if centerOpen: NotificationCenter shows NotifAppGroup list
```

---

## Rules

1. **No magic values.** All colors, sizes, and durations go in `Theme.qml` first, then reference `Theme.*`.
2. **Imports follow directory depth.** Components in `notifications/` use `import ".."`. Never skip levels.
3. **Asset paths from `notifications/`.** Reach `bar/assets/` with `"../../assets/filename.svg"`.
4. **Singletons stay in `modules/`.** A singleton needed by files in multiple directories must be registered in the master `modules/qmldir` so all subdirectories can reach it with `import ".."`.
5. **New singletons require a full restart.** Hot reload covers QML edits; qmldir/import changes do not.
6. **`NotifService._liveRefs[id]`** is a private map kept only to invoke notification actions. Access it only for action invocation, not for general state.

---

## Reload / Restart

```fish
# Hot reload (QML file edits — automatic, no action needed)

# Full restart (after qmldir or import changes):
qs kill -p /home/nexus/.config/quickshell/bar; and sleep 0.5; and qs -p /home/nexus/.config/quickshell/bar -d

# IPC — toggle notification center on a specific monitor:
qs -p /home/nexus/.config/quickshell/bar ipc call notifications toggle "DP-1"

# Check logs:
cat /run/user/1000/quickshell/by-id/<latest-id>/log.log
```

Find the latest instance ID with:
```fish
ls -lt /run/user/1000/quickshell/by-id/
```
