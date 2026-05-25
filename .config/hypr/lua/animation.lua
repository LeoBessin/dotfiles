-- ── Bezier curves ────────────────────────────────────────────────
hl.curve("wind",   { type = "bezier", points = { {0.05, 0.9},  {0.1,  1.05} } })
hl.curve("winIn",  { type = "bezier", points = { {0.1,  1.1},  {0.1,  1.1 } } })
hl.curve("winOut", { type = "bezier", points = { {0.3, -0.3},  {0,    1   } } })
hl.curve("liner",  { type = "bezier", points = { {1,    1   }, {1,    1   } } })

-- ── Global ───────────────────────────────────────────────────────
hl.animation({ leaf = "global",        enabled = true, speed = 1,  bezier = "default" })

-- ── Windows ──────────────────────────────────────────────────────
hl.animation({ leaf = "windows",       enabled = true, speed = 6,  bezier = "wind",   style = "slide" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 6,  bezier = "winIn",  style = "slide" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 5,  bezier = "winOut", style = "slide" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 5,  bezier = "wind",   style = "slide" })

-- ── Borders ──────────────────────────────────────────────────────
hl.animation({ leaf = "border",        enabled = true, speed = 4,  bezier = "wind" })
hl.animation({ leaf = "borderangle",   enabled = true, speed = 30, bezier = "liner",  style = "once" })

-- ── Fade ─────────────────────────────────────────────────────────
hl.animation({ leaf = "fade",          enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 8,  bezier = "wind" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 8,  bezier = "winOut" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "fadeLayers",    enabled = true, speed = 6,  bezier = "wind" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 6,  bezier = "winIn" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 5,  bezier = "winOut" })

-- ── Layers (rofi, waybar, notifications …) ───────────────────────
-- Per-namespace overrides live in windowrules.lua via hl.layer_rule
hl.animation({ leaf = "layers",        enabled = true, speed = 6,  bezier = "wind" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 6,  bezier = "winIn",  style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 5,  bezier = "winOut", style = "fade" })

-- ── Workspaces ───────────────────────────────────────────────────
hl.animation({ leaf = "workspaces",    enabled = true, speed = 5,  bezier = "wind" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 5,  bezier = "winIn" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 5,  bezier = "winOut" })
