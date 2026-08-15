#!/usr/bin/env bash
# F12 — End stream: play outro → stop stream when done (or cancel on second press)
set -euo pipefail

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

OBS="$HOME/.local/bin/obs-ws"
OUTRO_DUR="${OUTRO_DURATION:-300}"
PIDFILE="/tmp/stream_end.pid"

if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null; rm -f "$PIDFILE"
        $OBS scene "Live" 2>/dev/null
        command -v notify-send &>/dev/null && notify-send "Outro cancelled" "Stream still running"
        exit 0
    fi
    rm -f "$PIDFILE"
fi

$OBS scene "Outro" 2>/dev/null
sleep 0.5

(
    sleep "$OUTRO_DUR"
    $OBS stop-stream 2>/dev/null
    ~/.local/bin/stream_lofi.sh 2>/dev/null
    rm -f /tmp/stream{_brb,_go_live,_end}.pid
    command -v notify-send &>/dev/null && notify-send "Stream ended" "Goodbye!"
) &
echo $! > "$PIDFILE"
command -v notify-send &>/dev/null && notify-send "Ending stream" "Outro playing (${OUTRO_DUR}s) — press F12 to cancel"
