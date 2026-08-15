#!/usr/bin/env bash
set -euo pipefail

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

MIC_DEV="${STREAM_MIC_DEVICE:-alsa_input.pci-0000_00_1f.3.analog-stereo}"

CURRENT=$(pactl get-source-mute "$MIC_DEV" 2>/dev/null | awk '{print $2}') || {
    echo "ERROR: cannot read mute state for $MIC_DEV" >&2
    exit 1
}

if [ "$CURRENT" = "yes" ]; then
    pactl set-source-mute "$MIC_DEV" 0
    command -v notify-send &>/dev/null && notify-send -u low "Mic ON" "Unmuted"
else
    pactl set-source-mute "$MIC_DEV" 1
    command -v notify-send &>/dev/null && notify-send -u low "Mic OFF" "Muted"
fi
