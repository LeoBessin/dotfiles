-- Programs launched at Hyprland startup

hl.on("hyprland.start", function()
    -- Status bar
    hl.exec_cmd("qs -p ~/.config/quickshell/bar")

    -- Wallpaper daemon
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("awww img ~/Pictures/Wallpaper/horizon.jpg")

    -- Idle / lock manager
    hl.exec_cmd("hypridle")

    -- Notification daemon
    hl.exec_cmd("swaync")

    -- Network manager tray applet
    hl.exec_cmd("nm-applet --indicator")

    -- Polkit authentication agent
    hl.exec_cmd("hyprpolkitagent")

    -- XDG desktop portal (screen sharing, file picker)
    hl.exec_cmd("/usr/lib/xdg-desktop-portal-hyprland")

    -- Clipboard history daemon
    hl.exec_cmd("wl-paste --watch cliphist store")

    -- Color temperature (sunset)
    -- hl.exec_cmd("hyprsunset")
end)
