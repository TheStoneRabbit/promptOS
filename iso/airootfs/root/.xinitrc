#!/bin/sh
# promptOS X session.
# Launched by startx (see /etc/profile.d/00-promptos-x.sh) on the local console.
# Openbox is the window manager; the promptOS search-bar overlay is the primary
# interface and is started from openbox's autostart.

# Never blank/suspend the screen — the AI is an always-on operator surface.
xset s off -dpms 2>/dev/null || true

# Force GTK4 software rendering so the UI displays without GPU/DRI3 (e.g. in a
# VM). Remove on hardware with working GL if you want accelerated rendering.
export GSK_RENDERER=cairo
export GDK_BACKEND=x11

exec openbox-session
