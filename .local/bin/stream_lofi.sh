#!/usr/bin/env bash
# Toggle lofi background music during stream.
# When ducking is enabled, music level drops automatically when you speak.
# Plays through system audio — captured by the desktop monitor source.
#
# Config: ~/.config/stream.conf
#   LOFI_TRACK            path to mp3/m4a file or directory of tracks
#   LOFI_DUCKING=1        enable sidechain ducking (default: 1)
#   LOFI_DUCK_THRESHOLD   mic level to trigger duck (0.0–1.0, default: 0.02)
#   LOFI_DUCK_RATIO       compression ratio (default: 8)
#   LOFI_DUCK_LEVEL       duck strength (0.0=none, 1.0=full, default: 0.6)
#   LOFI_DUCK_ATTACK      attack time in ms (default: 5)
#   LOFI_DUCK_RELEASE     release time in ms (default: 300)

set -euo pipefail

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

PIDFILE="/tmp/stream_lofi.pid"
TRACK="${LOFI_TRACK:-$HOME/livestream/lofi.mp3}"
MIC_DEV="${STREAM_MIC_DEVICE:-alsa_input.pci-0000_00_1f.3.analog-stereo}"

LOFI_DUCKING="${LOFI_DUCKING:-1}"
LOFI_DUCK_THRESHOLD="${LOFI_DUCK_THRESHOLD:-0.02}"
LOFI_DUCK_RATIO="${LOFI_DUCK_RATIO:-8}"
LOFI_DUCK_LEVEL="${LOFI_DUCK_LEVEL:-0.6}"
LOFI_DUCK_ATTACK="${LOFI_DUCK_ATTACK:-5}"
LOFI_DUCK_RELEASE="${LOFI_DUCK_RELEASE:-300}"

if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        sleep 0.2
        kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
        rm -f "$PIDFILE"
        command -v notify-send &>/dev/null && notify-send "Lofi OFF" "Music stopped"
        exit 0
    fi
    rm -f "$PIDFILE"
fi

if [ -d "$TRACK" ]; then
    mapfile -t playlist < <(find "$TRACK" -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.flac" -o -iname "*.wav" \) | sort -R)
    if [ ${#playlist[@]} -eq 0 ]; then
        echo "ERROR: no audio files found in: $TRACK" >&2
        exit 1
    fi
    echo "Playing ${#playlist[@]} tracks from $TRACK (shuffled, looping)"

    CONCAT_FILE=$(mktemp /tmp/lofi_concat.XXXXXX)
    for f in "${playlist[@]}"; do
        echo "file '$f'" >> "$CONCAT_FILE"
    done
    FFMPEG_INPUTS=(-f concat -safe 0 -stream_loop -1 -i "$CONCAT_FILE")
    CONCAT_FILTER="[0:a]anull[a_loop]"
else
    if [ ! -f "$TRACK" ]; then
        echo "ERROR: lofi track not found: $TRACK" >&2
        exit 1
    fi
    echo "Playing: $TRACK"
    FFMPEG_INPUTS=(-stream_loop -1 -i "$TRACK")
    CONCAT_FILTER="[0:a]anull[a_loop]"
fi

cleanup_concat() {
    [ -n "${CONCAT_FILE:-}" ] && [ -f "$CONCAT_FILE" ] && rm -f "$CONCAT_FILE"
}
trap cleanup_concat EXIT

if [ "$LOFI_DUCKING" = "1" ]; then
    ffmpeg -f pulse -ar 48000 -t 1 -i "$MIC_DEV" -f null - 2>/dev/null || true
    sleep 0.3

    nohup ffmpeg -nostdin -hide_banner -loglevel error \
        "${FFMPEG_INPUTS[@]}" \
        -f pulse -ar 48000 -ac 2 -i "$MIC_DEV" \
        -filter_complex \
        "${CONCAT_FILTER}; \
         [1:a]highpass=f=80,lowpass=f=4000,volume=3[side]; \
         [a_loop][side]sidechaincompress=threshold=${LOFI_DUCK_THRESHOLD}:ratio=${LOFI_DUCK_RATIO}:level_sc=${LOFI_DUCK_LEVEL}:attack=${LOFI_DUCK_ATTACK}:release=${LOFI_DUCK_RELEASE}:link=average[out]" \
        -map "[out]" -f pulse default &>/dev/null &
else
    nohup ffplay -nodisp -loop 0 -loglevel quiet "$TRACK" &>/dev/null &
fi

PID=$!
sleep 1
if kill -0 "$PID" 2>/dev/null; then
    echo "$PID" > "$PIDFILE"
    DUCK_LABEL=""
    [ "$LOFI_DUCKING" = "1" ] && DUCK_LABEL=" (auto-duck)"
    command -v notify-send &>/dev/null && notify-send "Lofi ON" "Music playing${DUCK_LABEL}"
fi
