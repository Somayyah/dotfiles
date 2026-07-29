#!/usr/bin/env bash
set -euo pipefail

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

usage() {
    echo "Usage: $(basename "$0") <twitch-key> <youtube-key>"
    echo ""
    echo "Streams screen capture to Twitch AND YouTube simultaneously."
    echo "Config: \$HOME/.config/stream.conf"
    echo ""
    echo "Env vars (override config):"
    echo "  STREAM_TITLE=text        Text overlay on stream"
    echo "  STREAM_AUDIO_MODE=mode   desktop|mic|mix|track"
    echo "  STREAM_TRACK_FILE=file   Audio file to loop (mode=track)"
    exit 1
}

[ $# -ge 2 ] || usage

TWITCH_KEY="$1"
YOUTUBE_KEY="$2"

# ── Resolve config with defaults ──────────────────────────────────────────────

RESOLUTION="${STREAM_RESOLUTION:-$(xdpyinfo | awk '/dimensions/{print $2}')}"
DISPLAY_VAL="${DISPLAY:-:0}"

MIC_DEV="${STREAM_MIC_DEVICE:-alsa_input.pci-0000_00_1f.3.analog-stereo}"
DESKTOP_DEV="${STREAM_DESKTOP_DEVICE:-alsa_output.pci-0000_00_1f.3.analog-stereo.monitor}"

# ── Audio mode resolution ─────────────────────────────────────────────────────

AUDIO_MODE="${STREAM_AUDIO_MODE:-}"
if [ -z "$AUDIO_MODE" ]; then
    if   [ -n "${TRACK:-}" ];      then AUDIO_MODE="track";
    elif [ "${MIX:-}" = "1" ];      then AUDIO_MODE="mix";
    elif [ "${MIC:-}" = "1" ];      then AUDIO_MODE="mic";
    else                                 AUDIO_MODE="desktop"; fi
fi

TRACK_FILE="${STREAM_TRACK_FILE:-${TRACK:-}}"
MIC_FILTER_LEVEL="${STREAM_MIC_FILTER:-heavy}"

# ── Build audio chain ─────────────────────────────────────────────────────────

case "$AUDIO_MODE" in
    track)
        if [ -z "$TRACK_FILE" ]; then
            echo "ERROR: STREAM_AUDIO_MODE=track but no track file set (STREAM_TRACK_FILE)"
            exit 1
        fi
        if [ ! -f "$TRACK_FILE" ]; then
            echo "ERROR: file not found: $TRACK_FILE"
            exit 1
        fi
        echo "Audio: Track ($TRACK_FILE)"
        AUDIO_INPUTS=(-stream_loop -1 -i "$TRACK_FILE")
        AUDIO_FILTER="[1:a]anull[aout]"
        AUDIO_MAP="[aout]"
        ;;
    mic|mix)
        echo "Audio: ${AUDIO_MODE^} ($MIC_FILTER_LEVEL filter)"
        ffmpeg -f pulse -ar 48000 -i "$MIC_DEV" -t 1 -f null - 2>/dev/null || true
        sleep 1

        case "$MIC_FILTER_LEVEL" in
            off|none)
                MIC_CHAIN="anull"
                ;;
            light)
                MIC_CHAIN="highpass=f=80,lowpass=f=16000,afftdn=nr=15:nt=w"
                ;;
            standard)
                MIC_CHAIN="highpass=f=80,lowpass=f=16000,afftdn=nr=20:nt=w,agate=threshold=-40dB:ratio=2:attack=10:release=200:makeup=3,acompressor=threshold=-22dB:ratio=3:attack=5:release=100:makeup=2"
                ;;
            *)
                MIC_CHAIN="highpass=f=80,lowpass=f=16000,afftdn=nr=25:nt=w,agate=threshold=-42dB:ratio=3:attack=5:release=150:makeup=4,acompressor=threshold=-24dB:ratio=4:attack=2:release=80:makeup=3,alimiter=limit=0dB:attack=5:release=50"
                ;;
        esac

        if [ "$AUDIO_MODE" = "mic" ]; then
            AUDIO_INPUTS=(-thread_queue_size 8192 -f pulse -ar 48000 -ac 2 -i "$MIC_DEV")
            AUDIO_FILTER="[1:a]${MIC_CHAIN}[aout]"
        else
            AUDIO_INPUTS=(
                -thread_queue_size 8192 -f pulse -ar 48000 -ac 2 -i "$MIC_DEV"
                -thread_queue_size 8192 -f pulse -ar 48000 -ac 2 -i "$DESKTOP_DEV"
            )
            AUDIO_FILTER="[1:a]${MIC_CHAIN}[amic];[amic][2:a]amix=inputs=2:duration=longest:weights=1 0.5[aout]"
        fi
        AUDIO_MAP="[aout]"
        ;;
    *)
        echo "Audio: Desktop"
        AUDIO_INPUTS=(-thread_queue_size 8192 -f pulse -ar 48000 -ac 2 -i "$DESKTOP_DEV")
        AUDIO_FILTER="[1:a]anull[aout]"
        AUDIO_MAP="[aout]"
        ;;
esac

# ── Build title overlay ───────────────────────────────────────────────────────

TITLE="${STREAM_TITLE:-}"
if [ -n "$TITLE" ]; then
    printf '%s' "$TITLE" > /tmp/stream_title.txt
    TITLE_SIZE="${STREAM_TITLE_SIZE:-28}"
    echo "Title overlay: $TITLE"
    VIDEO_FILTER="[0:v]drawtext=textfile=/tmp/stream_title.txt:fontsize=${TITLE_SIZE}:fontcolor=white@0.7:x=10:y=h-th-14:box=1:boxcolor=black@0.3:boxborderw=6[vout]"
    VIDEO_MAP="[vout]"
else
    VIDEO_FILTER=""
    VIDEO_MAP="0:v"
fi

# ── Ingest URLs ───────────────────────────────────────────────────────────────

TWITCH_URL="${STREAM_TWITCH_URL:-rtmp://live.twitch.tv/app}"
YOUTUBE_URL="${STREAM_YOUTUBE_URL:-rtmp://a.rtmp.youtube.com/live2}"

echo "Mode: LIVE → Twitch + YouTube"
echo "Resolution: $RESOLUTION  |  Press Ctrl+C to stop."

# ── Intro video (before going live) ───────────────────────────────────────────

INTRO_VIDEO="${INTRO_VIDEO:-}"
INTRO_DURATION="${INTRO_DURATION:-300}"

if [ -n "$INTRO_VIDEO" ] && [ -f "$INTRO_VIDEO" ]; then
    echo "Intro: $INTRO_VIDEO (${INTRO_DURATION}s — press Q or Esc to skip)"
    timeout "$INTRO_DURATION" ffplay -fs -infbuf -nostats -loglevel quiet "$INTRO_VIDEO" 2>/dev/null || true
fi

# ── Encoding params ───────────────────────────────────────────────────────────

FPS="${STREAM_FPS:-30}"
PRESET="${STREAM_PRESET:-veryfast}"
GOP="${STREAM_GOP:-120}"
VIDEO_BITRATE="${STREAM_VIDEO_BITRATE:-2500k}"
MAXRATE="${STREAM_MAXRATE:-3000k}"
BUFSIZE="${STREAM_BUFSIZE:-5000k}"
AUDIO_BITRATE="${STREAM_AUDIO_BITRATE:-160k}"

X264_OPTS=""
[ -n "${STREAM_PROFILE:-}" ] && X264_OPTS="$X264_OPTS -profile:v ${STREAM_PROFILE}"
[ -n "${STREAM_TUNE:-}" ]   && X264_OPTS="$X264_OPTS -tune ${STREAM_TUNE}"

FILTER="${VIDEO_FILTER}${VIDEO_FILTER:+;}$AUDIO_FILTER"

# ── Run ───────────────────────────────────────────────────────────────────────

exec ffmpeg -hide_banner -loglevel info -stats \
    -thread_queue_size 8192 \
    -f x11grab -framerate "$FPS" -video_size "$RESOLUTION" -i "$DISPLAY_VAL" \
    "${AUDIO_INPUTS[@]}" \
    -filter_complex "$FILTER" \
    -map "$VIDEO_MAP" -map "$AUDIO_MAP" \
    -c:v libx264 -preset "$PRESET" -b:v "$VIDEO_BITRATE" -maxrate "$MAXRATE" -bufsize "$BUFSIZE" \
    $X264_OPTS \
    -pix_fmt yuv420p -g "$GOP" \
    -c:a aac -b:a "$AUDIO_BITRATE" -ar 48000 \
    -f tee \
    "[f=flv:flvflags=no_duration_filesize]$TWITCH_URL/$TWITCH_KEY|[f=flv:flvflags=no_duration_filesize]$YOUTUBE_URL/$YOUTUBE_KEY"
