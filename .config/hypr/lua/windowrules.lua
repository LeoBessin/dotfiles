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
    match = { class = "^(kitty|claude-code)$" },
    opacity = "0.80 0.80 1",
})

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
    "rofi",
    "notifications",
    "swaync-notification-window",
    "swaync-control-center",
    "logout_dialog",
    "quickshell-notif-center",
    "quickshell-bar",
}

for _, ns in ipairs(blur_namespaces) do
    hl.layer_rule({ match = { namespace = ns }, blur = true, ignore_alpha = 0 })
end

hl.layer_rule({ match = { namespace = "rofi" }, animation = "slide bottom 6 winIn" })

-- Waybar: explicitly no blur
hl.layer_rule({ match = { namespace = "waybar" }, blur = false })
