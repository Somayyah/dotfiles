#!/usr/bin/env bash
# F1 — Go live: play intro → start streaming → switch to Live when done
set -euo pipefail

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

OBS="$HOME/.local/bin/obs-ws"
INTRO_DUR="${INTRO_DURATION:-300}"
PIDFILE="/tmp/stream_go_live.pid"

if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null; rm -f "$PIDFILE"
        $OBS scene "Live" 2>/dev/null; $OBS stop-stream 2>/dev/null
        command -v notify-send &>/dev/null && notify-send "Stream cancelled" "Going-live aborted"
        exit 0
    fi
    rm -f "$PIDFILE"
fi

if pgrep -u "$USER" -f "obs.*x11grab\|obs.*libx264\|obs-ws start-stream" >/dev/null 2>&1; then
    command -v notify-send &>/dev/null && notify-send -u low "Already live" "Stream is running (F12 to stop)"
    exit 0
fi

$OBS scene "Starting Soon" 2>/dev/null
sleep 0.5
$OBS start-stream 2>/dev/null

(
    sleep "$INTRO_DUR"
    $OBS scene "Live" 2>/dev/null
    # Start lofi if not already playing
    if [ ! -f /tmp/stream_lofi.pid ]; then
        ~/.local/bin/stream_lofi.sh 2>/dev/null &
    fi
    rm -f "$PIDFILE"
) &
echo $! > "$PIDFILE"
command -v notify-send &>/dev/null && notify-send "Going live" "Intro playing (${INTRO_DUR}s)"
