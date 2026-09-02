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
│   ├── WeatherService.qml             # SINGLETON — Open-Meteo forecast polling
│   ├── BarWidget.qml                  # Base component for bar pill-widgets
│   ├── CalendarView.qml               # Calendar tab component
│   ├── WeatherWidget.qml              # Weather card (notification center)
│   ├── MediaPlayerWidget.qml          # MPRIS media player widget
│   ├── PowerButton.qml                # Reusable power action button
│   ├── notifications/
│   │   ├── qmldir                     # Notification UI components
│   │   ├── NotificationCenter.qml     # Slide-in panel (tabs: notifs, caffeine, weather, calendar, settings)
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

### Weather palette
| Property | Value | Use |
|---|---|---|
| `Theme.weatherTrackBg` | `rgba(1,1,1,0.12)` | Daily range-bar track |
| `Theme.weatherSunTint` | `#ffd27f` | Sunrise/sunset strip slot |
| `Theme.weatherRamp` | 6 stops, −10 → 32 °C | Cold→warm ramp for the range bars |

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
| `Theme.weatherTempSize` | 44px |
| `Theme.weatherIconSize` | 30px |
| `Theme.weatherHourIconSize` | 20px |
| `Theme.weatherDayRowHeight` | 24px |
| `Theme.weatherHourSlots` | 6 |
| `Theme.weatherDailyRows` | 5 |

### Animation & Timings
| Property | Value | Use |
|---|---|---|
| `Theme.animFast` | 120ms | Color/opacity transitions |
| `Theme.animMed` | 220ms | Slide/position animations |
| `Theme.toastDuration` | 5000ms | Toast auto-dismiss |
| `Theme.markReadDelay` | 800ms | Auto-read on panel open |
| `Theme.usageCacheMs` | 60000ms | Claude/Copilot usage cache TTL |
| `Theme.weatherPollMs` | 900000ms | Background forecast poll (Open-Meteo's own `current` interval) |
| `Theme.weatherStaleMs` | 600000ms | On-open refresh threshold; also drives the stale marker |
| `Theme.weatherRetryBaseMs` | 30000ms | First retry after a failed fetch, then doubling |
| `Theme.weatherHeartbeatMs` | 60000ms | Suspend / midnight detection tick |
| `Theme.weatherSuspendGapMs` | 150000ms | Wall-clock gap that means the machine was asleep |
| `Theme.weatherGeoTtlMs` | 21600000ms | IP-location re-resolve ceiling (6h) |

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

### `WeatherService`
Current conditions plus hourly/daily forecast from Open-Meteo (no API key). A single
request covers all three. Location comes from `config.json` when set, otherwise a
one-off `ip-api.com` lookup; both the location and the last good payload are cached
to `~/.local/share/quickshell/weather.json`, so the card is populated before the
first request returns and keeps showing last-known values while offline.

Optional `config.json` keys (see `Config.qml`) — `weatherLatitude` and
`weatherLongitude` only take effect as a pair, and setting them skips the
`ip-api.com` call entirely:

```json
{
  "weatherLatitude": 48.11,
  "weatherLongitude": -1.6744,
  "weatherLocationName": "Rennes",
  "weatherUnits": "metric"
}
```

```qml
WeatherService.ready             // bool — any data applied (cache or live)
WeatherService.loading           // bool
WeatherService.stale             // bool — reading older than Theme.weatherStaleMs
WeatherService.locationName      // string
WeatherService.temp              // real — current, in the configured unit
WeatherService.code              // int  — WMO weather code
WeatherService.isDay             // bool
WeatherService.todayMax          // real
WeatherService.todayMin          // real
WeatherService.hourlyModel       // ListModel — { label, code, isDay, temp, kind }
WeatherService.dailyModel        // ListModel — { label, code, minTemp, maxTemp }
WeatherService.weekMin/weekMax   // real — range-bar normalisation bounds

WeatherService.refresh()
WeatherService.refreshIfStale()  // called by NotificationCenter on open
WeatherService.codeIcon(code, isDay)   // Material Symbols glyph
WeatherService.codeLabel(code)         // "Mostly Clear", "Heavy Rain", …
WeatherService.tempColor(v)            // interpolated Theme.weatherRamp colour
```

Refresh cadence: 15 min background poll, an on-open check against
`Theme.weatherStaleMs`, exponential backoff on failure, and a 60 s heartbeat that
catches waking from suspend and rolling past midnight (which shifts what
"tomorrow" means for the daily rows).

Timestamps in the API response are wall-clock strings for the **forecast**
location with no offset, which is not necessarily this machine's timezone. Never
hand them to `Date.parse` directly — go through the private `_apiMs()`, which
applies the `utc_offset_seconds` the API reports. Display labels are sliced
straight out of the strings so they read in the location's own time.

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
7. **`ListModel` roles are fixed at the first append.** A later object with a
   different key set silently loses the missing roles, and the delegate renders
   blank. `WeatherService._buildHourly` appends an explicit fixed role set for
   exactly this reason — the "Now" slot and the sunrise/sunset slot must carry
   the same keys as a plain forecast hour.
8. **Re-assigning `Process.running` kills a live process.** Several things ask
   for a weather fetch at once on startup (cache load, fallback timer, config
   arriving late); `WeatherService._fetchWeather` guards on `running` so they do
   not abort each other into a spurious failure and backoff.
9. **Fullscreen overlays declare their own blur region.** A new `PanelWindow` that is a fullscreen transparent surface with a card inside must set `BackgroundEffect.blurRegion: Region { item: <card>; radius: <card radius> }` (`import Quickshell.Wayland`). A compositor-side `blur true` layer rule would blur the whole screen, because it applies to the surface rectangle and neither niri nor the region protocol looks at per-pixel alpha. The matching `xray false` layer rules live in `contrib/niri/config.kdl` — without them niri blurs the wallpaper instead of the windows actually behind the card.

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
