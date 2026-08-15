#!/usr/bin/env bash
# Toggle BRB screen — plays video fullscreen, mutes mic during break.
# Config: ~/.config/stream.conf  (BRB_VIDEO, STREAM_MIC_DEVICE)
set -euo pipefail

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

PIDFILE="/tmp/stream_brb.pid"
VIDEO="${BRB_VIDEO:-$HOME/livestream/BRB.mp4}"
MIC_DEV="${STREAM_MIC_DEVICE:-alsa_input.pci-0000_00_1f.3.analog-stereo}"

if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        sleep 0.2
        kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
    pactl set-source-mute "$MIC_DEV" 0
    command -v notify-send &>/dev/null && notify-send "Stream resumed" "Break is over"
    exit 0
fi

[ -f "$VIDEO" ] || { echo "ERROR: BRB video not found: $VIDEO" >&2; exit 1; }

pactl set-source-mute "$MIC_DEV" 1
nohup ffplay -fs -infbuf -nostats -loglevel quiet "$VIDEO" &>/dev/null &
PID=$!
sleep 0.5
if kill -0 "$PID" 2>/dev/null; then
    echo "$PID" > "$PIDFILE"
    command -v notify-send &>/dev/null && notify-send "Stream break" "Mic muted — press hotkey to resume"
fi
