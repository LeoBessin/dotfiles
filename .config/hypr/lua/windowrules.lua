-- Window rules, layer rules, and workspace rules

-- ──────────────────────────────────────────────────────
-- Idle inhibit: prevent sleep when video is playing fullscreen
-- ──────────────────────────────────────────────────────
hl.window_rule({
    name  = "idle-inhibit-video",
    match = { class = "^(.*celluloid.*|.*mpv.*|.*vlc.*)$" },
    idle_inhibit = "fullscreen",
})

hl.window_rule({
    name  = "idle-inhibit-spotify",
    match = { class = "^(.*[Ss]potify.*)$" },
    idle_inhibit = "fullscreen",
})

hl.window_rule({
    name  = "idle-inhibit-browsers",
    match = { class = "^(.*LibreWolf.*|.*floorp.*|.*brave-browser.*|.*firefox.*|.*chromium.*|.*zen.*|.*vivaldi.*)$" },
    idle_inhibit = "fullscreen",
})

-- ──────────────────────────────────────────────────────
-- Picture-in-Picture
-- ──────────────────────────────────────────────────────
hl.window_rule({
    name  = "picture-in-picture",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float            = true,
    keep_aspect_ratio = true,
    move             = "(monitor_w*0.73) (monitor_h*0.72)",
    size             = "(monitor_w*0.25) (monitor_h*0.25)",
    pin              = true,
})

-- ──────────────────────────────────────────────────────
-- Opacity
-- ──────────────────────────────────────────────────────
hl.window_rule({
    name  = "opacity-terminals",
    match = { class = "^claude-code$" },
    opacity = "0.80 0.80 1",
})

-- kitty has no window rule of its own. It is deliberately absent from
-- opacity-terminals above: it sets `background_opacity 0.55` (= Theme.bg alpha)
-- itself in ~/.config/kitty/kitty.conf, which fades only the background, whereas
-- an `opacity` rule would fade the glyphs too — and the bar's text is opaque.
-- The bar-derived border and the 10px Theme.radius are global (options.lua), and
-- blur is global here too, so there is nothing left to override.
-- Mirrored for niri in ~/.config/niri/window-rules.kdl.

hl.window_rule({
    name  = "ai-picker",
    match = { class = "^ai-picker$" },
    float   = true,
    center  = true,
    size    = "700 500",
    opacity = "0.70 0.70 1",
})

-- ──────────────────────────────────────────────────────
-- Float rules
-- ──────────────────────────────────────────────────────
local float_classes = {
    "^Signal$",
    "^com.github.rafostar.Clapper$",
    "^app.drey.Warp$",
    "^net.davidotek.pupgui2$",
    "^yad$",
    "^eog$",
    "^io.github.alainm23.planify$",
    "^io.gitlab.theevilskeleton.Upscaler$",
    "^com.github.unrud.VideoDownloader$",
    "^io.gitlab.adhami3310.Impression$",
    "^io.missioncenter.MissionCenter$",
}

for _, cls in ipairs(float_classes) do
    hl.window_rule({ match = { class = cls }, float = true })
end

hl.window_rule({ match = { title = "^Friends List$"   }, float = true })
hl.window_rule({ match = { title = "^Steam Settings$" }, float = true })

-- ──────────────────────────────────────────────────────
-- Jetbrains IDE: suppress popup flicker
-- ──────────────────────────────────────────────────────
hl.window_rule({
    name  = "jetbrains-no-focus",
    match = { class = "^(.*jetbrains.*)$", title = "^(win[0-9]+)$" },
    no_initial_focus = true,
})

-- ──────────────────────────────────────────────────────
-- Suppress maximize requests globally
-- ──────────────────────────────────────────────────────
hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- ──────────────────────────────────────────────────────
-- Fix XWayland drag popups
-- ──────────────────────────────────────────────────────
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- ──────────────────────────────────────────────────────
-- Layer rules
-- ──────────────────────────────────────────────────────
local blur_namespaces = {
    "rofi",             -- kept as themed fallback launcher
    "logout_dialog",    -- wlogout (Ctrl+Alt+Delete)
    "quickshell-notif-center",
    "quickshell-toasts",
    "quickshell-bar",
    "quickshell-launcher",
    "quickshell-workspaces",
    "quickshell-ai-panel",
    "quickshell-totp-panel",
}

for _, ns in ipairs(blur_namespaces) do
    hl.layer_rule({ match = { namespace = ns }, blur = true, ignore_alpha = 0 })
end

hl.layer_rule({ match = { namespace = "rofi" },              animation = "slide bottom 6 winIn" })
hl.layer_rule({ match = { namespace = "quickshell-launcher" }, animation = "slide bottom 10 wind" })
