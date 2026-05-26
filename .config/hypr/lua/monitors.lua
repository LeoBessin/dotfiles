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
    mode     = "1920x1080@60",
    position = "2313x999",
    scale    = 1.0,
})

-- Fallback: any unknown monitor uses preferred mode
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Re-apply HDMI config when the monitor is hotplugged
hl.on("monitor.added", function(monitor)
    if monitor.name == "HDMI-A-1" then
        hl.exec_cmd("bash ~/.config/hypr/scripts/setup-hdmi.sh")
    end
end)

-- Re-apply HDMI config on every config reload
hl.on("config.reloaded", function()
    hl.exec_cmd("bash ~/.config/hypr/scripts/setup-hdmi.sh")
end)
