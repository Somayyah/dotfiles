#!/usr/bin/env bash
# Play outro fullscreen (mic muted), then end stream when outro finishes.
# Press once — outro plays + mic muted → stream stops.
# Press again — cancel.
# Config: ~/.config/stream.conf  (OUTRO_VIDEO, OUTRO_DURATION, STREAM_MIC_DEVICE)
set -euo pipefail

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

PIDFILE="/tmp/stream_outro.pid"
VIDEO="${OUTRO_VIDEO:-$HOME/livestream/end.mp4}"
DURATION="${OUTRO_DURATION:-300}"
MIC_DEV="${STREAM_MIC_DEVICE:-alsa_input.pci-0000_00_1f.3.analog-stereo}"

if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        sleep 0.2
        kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
    pactl set-source-mute "$MIC_DEV" 0
    command -v notify-send &>/dev/null && notify-send "Outro cancelled" "Stream still running, mic unmuted"
    exit 0
fi

[ -f "$VIDEO" ] || { echo "ERROR: outro video not found: $VIDEO" >&2; exit 1; }

pactl set-source-mute "$MIC_DEV" 1

(
    nohup ffplay -fs -infbuf -nostats -loglevel quiet "$VIDEO" &>/dev/null
    STREAM_PID=$(pgrep -u "$USER" -f "x11grab.*libx264" 2>/dev/null | head -1 || true)
    if [ -n "$STREAM_PID" ]; then
        kill -INT "$STREAM_PID" 2>/dev/null || true
    fi
    rm -f /tmp/stream_brb.pid /tmp/stream_intro.pid /tmp/stream.status /tmp/stream_outro.pid
    command -v notify-send &>/dev/null && notify-send "Stream ended" "Goodbye!"
) &

echo $! > "$PIDFILE"
rm -f /tmp/stream_brb.pid /tmp/stream_intro.pid
command -v notify-send &>/dev/null && notify-send "Ending stream" "Outro playing (${DURATION}s), mic muted — press F12 to cancel"
