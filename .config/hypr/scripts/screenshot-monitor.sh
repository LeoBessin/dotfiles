#!/bin/bash
monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
grim -o "$monitor" - | wl-copy
