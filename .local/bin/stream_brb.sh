#!/usr/bin/env bash
# Toggle BRB screen — plays video fullscreen with ffplay.
# Bind to a hotkey (GNOME Settings > Keyboard > Shortcuts).
#
# Config: ~/.config/stream.conf  (BRB_VIDEO)

set -euo pipefail

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

PIDFILE="/tmp/stream_brb.pid"
VIDEO="${BRB_VIDEO:-$HOME/livestream/BRB.mp4}"

if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        rm -f "$PIDFILE"
        command -v notify-send &>/dev/null && notify-send "Stream resumed" "Break is over"
        exit 0
    fi
    rm -f "$PIDFILE"
fi

[ -f "$VIDEO" ] || { echo "ERROR: BRB video not found: $VIDEO" >&2; exit 1; }

ffplay -fs -loop 0 -infbuf -nostats -loglevel quiet "$VIDEO" &
PID=$!
sleep 1
if kill -0 "$PID" 2>/dev/null; then
    echo "$PID" > "$PIDFILE"
    command -v notify-send &>/dev/null && notify-send "Stream break" "Press hotkey to resume"
fi
