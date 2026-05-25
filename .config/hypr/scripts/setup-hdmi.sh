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
    RES="2560x1440@60"
    Y=639
else
    RES="1920x1080@60"
    Y=999
fi

hyprctl keyword monitor "${MONITOR},${RES},${X}x${Y},1.0"
