#!/usr/bin/env bash
# Applies the best available resolution to HDMI-A-1.
# Bottom-aligned with eDP-1 (laptop screen bottom = y 2079).

MONITOR="HDMI-A-1"
X=2313

if ! hyprctl monitors all | grep -q "Monitor ${MONITOR} "; then
    exit 0
fi

MODES=$(hyprctl -j monitors all | jq -r ".[] | select(.name == \"${MONITOR}\") | .availableModes[]")

if echo "$MODES" | grep -q "^2560x1440"; then
    RES=$(echo "$MODES" | grep "^2560x1440@60" | head -1)
    [ -z "$RES" ] && RES=$(echo "$MODES" | grep "^2560x1440" | head -1)
    Y=639
else
    RES=$(echo "$MODES" | grep "^1920x1080@60" | head -1)
    [ -z "$RES" ] && RES="1920x1080@60.00Hz"
    Y=999
fi

hyprctl eval "hl.monitor({ output = \"${MONITOR}\", mode = \"${RES}\", position = \"${X}x${Y}\", scale = 1.0 })"
