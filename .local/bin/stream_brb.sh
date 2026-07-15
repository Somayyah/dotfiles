#!/usr/bin/env bash
# stream_brb.sh - Toggle break screen overlay for streaming
# Bind this to a hotkey in GNOME Settings > Keyboard > Shortcuts
#
# Config: $HOME/.config/stream.conf  (BRB_MESSAGE, BRB_IMAGE)

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

PIDFILE="/tmp/stream_brb.pid"
export BRB_MSG="${BRB_MESSAGE:-STREAM ON BREAK}"
export BRB_IMG="${BRB_IMAGE:-}"

if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        rm -f "$PIDFILE"
        if command -v notify-send &>/dev/null; then
            notify-send -i media-playback-start "Stream resumed" "Break is over"
        fi
        exit 0
    fi
    rm -f "$PIDFILE"
fi

nohup python3 "$HOME/dotfiles/.local/bin/stream_brb.py" &>/dev/null &
PID=$!
sleep 1
if kill -0 "$PID" 2>/dev/null; then
    echo "$PID" > "$PIDFILE"
    if command -v notify-send &>/dev/null; then
        notify-send -i media-playback-pause "Stream break" "Press hotkey again to resume"
    fi
fi
