#!/bin/sh
# Open Portainer and focus the browser window showing it.
#
# `xdg-open` alone hands the URL to the already-running browser, which then
# asks to be raised — but a process spawned from the bar carries no
# XDG_ACTIVATION_TOKEN, so niri correctly refuses the focus-steal and the tab
# opens behind whatever you were doing. Focus it explicitly instead.
set -e

URL="http://localhost:9001"

xdg-open "$URL" >/dev/null 2>&1 &

# The tab needs a moment to exist before its title mentions Portainer.
i=0
while [ "$i" -lt 20 ]; do
    id=$(niri msg -j windows 2>/dev/null | python3 -c '
import json, sys
try:
    ws = json.load(sys.stdin)
except Exception:
    sys.exit(0)

def pick(pred):
    m = [w["id"] for w in ws if pred(w)]
    return m[0] if m else None

# Prefer the window actually showing Portainer; otherwise the plain browser
# window the tab most likely landed in (not a PWA/app-mode window).
hit = pick(lambda w: "portainer" in (w.get("title") or "").lower()) \
   or pick(lambda w: (w.get("app_id") or "") in ("brave-browser", "chromium", "firefox"))
if hit is not None:
    print(hit)
')
    if [ -n "$id" ]; then
        niri msg action focus-window --id "$id" >/dev/null 2>&1 || true
        exit 0
    fi
    i=$((i + 1))
    sleep 0.15
done
