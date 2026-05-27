-- Keybindings

local M   = "SUPER"
local MA  = "SUPER + ALT"
local MS  = "SUPER + SHIFT"
local MC  = "SUPER + CTRL"
local MCA = "SUPER + CTRL + ALT"
local MCS = "SUPER + CTRL + SHIFT"

local terminal    = "kitty"
local editor      = "code"
local explorer    = "dolphin"
local browser     = "brave"

-- ──────────────────────────────────────────────────────
-- Window management
-- ──────────────────────────────────────────────────────
hl.bind(M .. " + Q",          hl.dsp.window.close(),                          { description = "close focused window" })
hl.bind("ALT + F4",           hl.dsp.window.close(),                          { description = "close focused window" })
hl.bind(M .. " + DELETE",     hl.dsp.exec_cmd("hyprctl dispatch exit"),        { description = "kill hyprland session" })
hl.bind(M .. " + W",          hl.dsp.window.float({ action = "toggle" }),      { description = "toggle floating" })
hl.bind(M .. " + G",          hl.dsp.exec_cmd("hyprctl dispatch togglegroup"), { description = "toggle group" })
hl.bind("SHIFT + F11",        hl.dsp.window.fullscreen(),                      { description = "toggle fullscreen" })
hl.bind(M .. " + L",          hl.dsp.exec_cmd("loginctl lock-session"),        { description = "lock screen" })
hl.bind(M .. " + J",          hl.dsp.layout("togglesplit"),                   { description = "toggle split" })


hl.bind(MS .. " + F",         hl.dsp.exec_cmd("hyprctl dispatch pin"),         { description = "pin focused window" })
hl.bind("CTRL + ALT + DELETE", hl.dsp.exec_cmd("wlogout"),                    { description = "logout menu" })
hl.bind("Alt_R + Control_R",  hl.dsp.exec_cmd("pkill qs || qs -p ~/.config/quickshell/bar"), { description = "toggle bar" })

-- Group navigation
hl.bind(MC .. " + H", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive b"), { description = "previous group window" })
hl.bind(MC .. " + L", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive f"), { description = "next group window" })

-- Focus
hl.bind(M .. " + LEFT",  hl.dsp.focus({ direction = "left"  }), { description = "focus left" })
hl.bind(M .. " + RIGHT", hl.dsp.focus({ direction = "right" }), { description = "focus right" })
hl.bind(M .. " + UP",    hl.dsp.focus({ direction = "up"    }), { description = "focus up" })
hl.bind(M .. " + DOWN",  hl.dsp.focus({ direction = "down"  }), { description = "focus down" })
hl.bind("ALT + TAB",     hl.dsp.exec_cmd("hyprctl --batch 'dispatch cyclenext ; dispatch alterzorder top'"), { description = "cycle focus" })

-- Resize (held)
hl.bind(MS .. " + RIGHT", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 30 0"),  { release = true, description = "resize right" })
hl.bind(MS .. " + LEFT",  hl.dsp.exec_cmd("hyprctl dispatch resizeactive -30 0"), { release = true, description = "resize left" })
hl.bind(MS .. " + UP",    hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -30"), { release = true, description = "resize up" })
hl.bind(MS .. " + DOWN",  hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 30"),  { release = true, description = "resize down" })

-- Move active window (smart float/tile)
local movewin = "grep -q 'true' <<< $(hyprctl activewindow -j | jq -r .floating) && hyprctl dispatch moveactive"
hl.bind(MCS .. " + LEFT",  hl.dsp.exec_cmd(movewin .. " -30 0 || hyprctl dispatch movewindow l"), { release = true, description = "move window left" })
hl.bind(MCS .. " + RIGHT", hl.dsp.exec_cmd(movewin .. "  30 0 || hyprctl dispatch movewindow r"), { release = true, description = "move window right" })
hl.bind(MCS .. " + UP",    hl.dsp.exec_cmd(movewin .. "  0 -30 || hyprctl dispatch movewindow u"), { release = true, description = "move window up" })
hl.bind(MCS .. " + DOWN",  hl.dsp.exec_cmd(movewin .. "  0 30 || hyprctl dispatch movewindow d"), { release = true, description = "move window down" })

-- Mouse move / resize
hl.bind(M .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "drag window" })
hl.bind(M .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "resize window" })
hl.bind(M .. " + Z",         hl.dsp.window.drag(),   { mouse = true, description = "drag window (keyboard)" })
hl.bind(M .. " + X",         hl.dsp.window.resize(), { mouse = true, description = "resize window (keyboard)" })

-- ──────────────────────────────────────────────────────
-- Launchers
-- ──────────────────────────────────────────────────────
hl.bind(M .. " + T",          hl.dsp.exec_cmd(terminal),                                 { description = "terminal" })
hl.bind(M .. " + E",          hl.dsp.exec_cmd(explorer),                                 { description = "file explorer" })
hl.bind(M .. " + C",          hl.dsp.exec_cmd(editor),                                   { description = "text editor" })
hl.bind(M .. " + B",          hl.dsp.exec_cmd(browser),                                  { description = "web browser" })
hl.bind("CTRL + SHIFT + ESCAPE", hl.dsp.exec_cmd("kitty btop"),                          { description = "system monitor" })
hl.bind("XF86Assistant",      hl.dsp.exec_cmd("kitty --class ai-picker -e ai-cli-picker"), { description = "AI CLI launcher" })

-- Rofi menus
hl.bind("ALT + SPACE",    hl.dsp.exec_cmd("pkill -x rofi || rofi -show drun -p 'Open'"),              { description = "application finder" })
hl.bind(M .. " + TAB",   hl.dsp.exec_cmd("pkill -x rofi || rofi -show window"),             { description = "window switcher" })
hl.bind(MS .. " + E",    hl.dsp.exec_cmd("pkill -x rofi || rofi -show filebrowser"),        { description = "file finder" })
hl.bind(M .. " + COMMA", hl.dsp.exec_cmd("pkill -x rofi || rofimoji --files emojis --selector-args '-theme /home/nexus/.config/rofi/list.rasi'"),         { description = "emoji picker" })
hl.bind(M .. " + PERIOD", hl.dsp.exec_cmd("pkill -x rofi || rofimoji --files nerd_font --selector-args '-theme /home/nexus/.config/rofi/list.rasi'"),    { description = "icon picker" })
hl.bind(M .. " + V",     hl.dsp.exec_cmd("pkill -x rofi || cliphist list | rofi -dmenu -p 'Copy' -theme ~/.config/rofi/list.rasi -theme-str 'entry { placeholder: \"Search history...\"; }' | cliphist decode | wl-copy"), { description = "clipboard picker" })
hl.bind(MS .. " + V",    hl.dsp.exec_cmd("pkill -x rofi || cliphist list | rofi -dmenu -p 'Copy' -theme ~/.config/rofi/list.rasi -theme-str 'entry { placeholder: \"Search history...\"; }' | cliphist decode | wl-copy"), { description = "clipboard manager" })

-- ──────────────────────────────────────────────────────
-- Hardware controls
-- ──────────────────────────────────────────────────────

-- Volume
hl.bind("F10",                   hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),      { locked = true, description = "toggle mute" })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),      { locked = true, description = "toggle mute" })
hl.bind("F11",                   hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),       { locked = true, repeating = true, description = "volume down" })
hl.bind("F12",                   hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "volume up" })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),       { locked = true, repeating = true, description = "volume down" })
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "volume up" })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, description = "toggle mic mute" })

-- Media
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "play/pause" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "pause" })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "next track" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "previous track" })

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true, description = "brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true, description = "brightness down" })

-- ──────────────────────────────────────────────────────
-- Utilities
-- ──────────────────────────────────────────────────────
hl.bind(M .. " + N",  hl.dsp.exec_cmd("qs msg -c bar notifications toggle \"$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')\""), { description = "toggle notification center" })
hl.bind(M .. " + K",  hl.dsp.exec_cmd("hyprctl switchxkblayout all next"),            { description = "next keyboard layout" })
hl.bind(MC .. " + M", hl.dsp.exec_cmd("~/.config/hypr/scripts/window-mute.sh"),       { description = "mute active window audio" })

-- Screenshots (grim + slurp)
hl.bind(MS .. " + P",    hl.dsp.exec_cmd("hyprpicker -an"),                              { description = "color picker" })
hl.bind(M .. " + P",     hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'),             { description = "screenshot region" })
hl.bind(MC .. " + P",    hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'),             { description = "screenshot region" })
hl.bind(MA .. " + P",    hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot-monitor.sh"),             { locked = true, description = "screenshot monitor" })
hl.bind("PRINT",          hl.dsp.exec_cmd("grim - | wl-copy"),                           { locked = true, description = "screenshot all monitors" })

-- ──────────────────────────────────────────────────────
-- Workspaces
-- ──────────────────────────────────────────────────────
for i = 1, 10 do
    local key = i % 10  -- maps 10 → key 0
    hl.bind(M  .. " + " .. key, hl.dsp.focus({ workspace = i }),                          { description = "workspace " .. i })
    hl.bind(MS .. " + " .. key, hl.dsp.window.move({ workspace = i }),                    { description = "move to workspace " .. i })
    hl.bind(MA .. " + " .. key, hl.dsp.window.move({ workspace = i, silent = true }),     { description = "move silently to workspace " .. i })
end

-- Relative workspace navigation
hl.bind(MC .. " + RIGHT", hl.dsp.focus({ workspace = "r+1" }), { description = "next workspace" })
hl.bind(MC .. " + LEFT",  hl.dsp.focus({ workspace = "r-1" }), { description = "previous workspace" })
hl.bind(MC .. " + DOWN",  hl.dsp.focus({ workspace = "empty" }), { description = "nearest empty workspace" })

-- Relative window-to-workspace moves
hl.bind(MCA .. " + RIGHT", hl.dsp.window.move({ workspace = "r+1" }), { description = "move window to next workspace" })
hl.bind(MCA .. " + LEFT",  hl.dsp.window.move({ workspace = "r-1" }), { description = "move window to previous workspace" })

-- Scroll through workspaces
hl.bind(M .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "scroll to next workspace" })
hl.bind(M .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "scroll to previous workspace" })

-- Special workspace (scratchpad)
hl.bind(MS .. " + S",  hl.dsp.window.move({ workspace = "special" }),               { description = "move to scratchpad" })
hl.bind(MA .. " + S",  hl.dsp.window.move({ workspace = "special", silent = true }), { description = "move to scratchpad (silent)" })
hl.bind(M  .. " + S",  hl.dsp.workspace.toggle_special(),                            { description = "toggle scratchpad" })
