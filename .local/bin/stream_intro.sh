#!/usr/bin/env bash
# Toggle intro screen — plays starting_soon.mp4 fullscreen, looping.
# Press hotkey again (or Ctrl+C the ffplay window) to stop and start the stream.
#
# Config: ~/.config/stream.conf  (INTRO_VIDEO)

set -euo pipefail

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

PIDFILE="/tmp/stream_intro.pid"
VIDEO="${INTRO_VIDEO:-$HOME/livestream/starting_soon.mp4}"

if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        rm -f "$PIDFILE"
        command -v notify-send &>/dev/null && notify-send "Intro ended" "Stream starting"
        exit 0
    fi
    rm -f "$PIDFILE"
fi

[ -f "$VIDEO" ] || { echo "ERROR: intro video not found: $VIDEO" >&2; exit 1; }

ffplay -fs -loop 0 -infbuf -nostats -loglevel quiet "$VIDEO" &
PID=$!
sleep 1
if kill -0 "$PID" 2>/dev/null; then
    echo "$PID" > "$PIDFILE"
    command -v notify-send &>/dev/null && notify-send "Starting soon" "Intro playing — press hotkey when ready"
fi
