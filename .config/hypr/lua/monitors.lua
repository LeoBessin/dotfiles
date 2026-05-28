-- Monitor configuration
-- Positions match the nwg-displays layout (laptop center-left, HDMI to the right with slight vertical offset)

hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1200@60",
    position = "393x879",
    scale    = 1.0,
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "preferred",
    position = "auto",
    scale    = 1.0,
})

-- Fallback: any unknown monitor uses preferred mode
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
