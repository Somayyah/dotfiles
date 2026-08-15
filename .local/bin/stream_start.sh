#!/usr/bin/env bash
set -euo pipefail

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

if pgrep -u "$USER" -f "x11grab.*libx264" >/dev/null 2>&1; then
    command -v notify-send &>/dev/null && notify-send -u low "Already live" "Stream is running (F12 to stop)"
    exit 0
fi

PLATFORM="${STREAM_PLATFORM:-youtube}"

notify() { command -v notify-send &>/dev/null && notify-send "$1" "$2"; }

case "$PLATFORM" in
    youtube)
        KEY="${STREAM_KEY_YOUTUBE:-}"
        [ -n "$KEY" ] || { notify "Stream Error" "STREAM_KEY_YOUTUBE not set in ~/.config/stream.conf"; exit 1; }
        ;;
    twitch)
        KEY="${STREAM_KEY_TWITCH:-}"
        [ -n "$KEY" ] || { notify "Stream Error" "STREAM_KEY_TWITCH not set in ~/.config/stream.conf"; exit 1; }
        ;;
    *)
        notify "Stream Error" "Unknown platform: $PLATFORM (use youtube or twitch)"
        exit 1
        ;;
esac

export STREAM_PLATFORM="$PLATFORM"
export STREAM_KEY="$KEY"
systemd-run --user --scope --quiet ~/.local/bin/stream.sh "$PLATFORM" &>/dev/null &
disown
notify "Going live" "Streaming → ${PLATFORM^}"
