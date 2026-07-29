#!/usr/bin/env bash
# End the stream and play outro video for 5 minutes.
# Bind to F12 (GNOME Settings > Keyboard > Shortcuts).
#
# Config: ~/.config/stream.conf  (OUTRO_VIDEO, OUTRO_DURATION)

set -euo pipefail

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

VIDEO="${OUTRO_VIDEO:-$HOME/livestream/end.mp4}"
DURATION="${OUTRO_DURATION:-300}"

[ -f "$VIDEO" ] || { echo "ERROR: outro video not found: $VIDEO" >&2; exit 1; }

STREAM_PID=$(pgrep -u "$USER" -f "x11grab.*libx264" 2>/dev/null | head -1 || true)

if [ -n "$STREAM_PID" ]; then
    kill -INT "$STREAM_PID" 2>/dev/null || true
    notify-send "Stream ending" "Outro playing for ${DURATION}s..."
fi

timeout "$DURATION" ffplay -fs -loop 0 -infbuf -nostats -loglevel quiet "$VIDEO" 2>/dev/null || true

rm -f /tmp/stream_brb.pid /tmp/stream_intro.pid
notify-send "Stream ended" "Goodbye!"
