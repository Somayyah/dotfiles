#!/usr/bin/env bash
set -euo pipefail

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

usage() {
    echo "Usage: $(basename "$0") [platform] [stream-key]"
    echo ""
    echo "Platforms:"
    echo "  twitch         rtmp://live.twitch.tv/app/<key>"
    echo "  twitch-test    Twitch bandwidth test (NOT live)"
    echo "  youtube        rtmp://a.rtmp.youtube.com/live2/<key>"
    echo "  rtmp <url>     Custom RTMP URL"
    echo "  file <path>    Save to local file for testing"
    echo ""
    echo "Key can be passed as arg or set in:"
    echo "  \$STREAM_KEY              env var"
    echo "  STREAM_KEY_TWITCH          in ~/.config/stream.conf"
    echo "  STREAM_KEY_YOUTUBE         in ~/.config/stream.conf"
    echo ""
    echo "Platform can be passed as arg or set as STREAM_PLATFORM in config."
    echo ""
    echo "Other env vars (override config):"
    echo "  STREAM_TITLE=text        Text overlay on stream"
    echo "  STREAM_AUDIO_MODE=mode   desktop|mic|mix|track"
    echo "  STREAM_TRACK_FILE=file   Audio file to loop (mode=track)"
    exit 1
}

if [ $# -eq 0 ]; then
    PLATFORM="${STREAM_PLATFORM:-}"
    [ -n "$PLATFORM" ] || { echo "ERROR: STREAM_PLATFORM not set (config or env)" >&2; usage; }
    KEY="${STREAM_KEY:-}"
elif [ $# -eq 1 ]; then
    PLATFORM="$1"
    KEY="${STREAM_KEY:-}"
else
    PLATFORM="$1"; KEY="$2"
fi
[ -n "$KEY" ] || [ "$PLATFORM" = "file" ] || { echo "ERROR: no stream key provided (pass as arg or set STREAM_KEY)" >&2; usage; }

# ── Resolve config with defaults ──────────────────────────────────────────────

RESOLUTION="${STREAM_RESOLUTION:-$(xdpyinfo | awk '/dimensions/{print $2}')}"
DISPLAY_VAL="${DISPLAY:-:0}"

MIC_DEV="${STREAM_MIC_DEVICE:-alsa_input.pci-0000_00_1f.3.analog-stereo}"
DESKTOP_DEV="${STREAM_DESKTOP_DEVICE:-alsa_output.pci-0000_00_1f.3.analog-stereo.monitor}"

# ── Audio mode resolution (config file takes priority, then legacy env vars) ──

AUDIO_MODE="${STREAM_AUDIO_MODE:-}"
if [ -z "$AUDIO_MODE" ]; then
    if   [ -n "${TRACK:-}" ];      then AUDIO_MODE="track";
    elif [ "${MIX:-}" = "1" ];      then AUDIO_MODE="mix";
    elif [ "${MIC:-}" = "1" ];      then AUDIO_MODE="mic";
    else                                 AUDIO_MODE="desktop"; fi
fi

TRACK_FILE="${STREAM_TRACK_FILE:-${TRACK:-}}"
MIC_FILTER_LEVEL="${STREAM_MIC_FILTER:-heavy}"

# Mute mic during intro if configured
INTRO_MUTE=0
INTRO_MUTE_DUR="${INTRO_DURATION:-300}"
if [ -n "${INTRO_VIDEO:-}" ] && [ -f "$INTRO_VIDEO" ]; then
    INTRO_MUTE=1
fi

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
                MIC_CHAIN="highpass=f=80,lowpass=f=12000,afftdn=nr=20:nt=w,agate=threshold=-40dB:ratio=2:attack=10:release=200:makeup=3,acompressor=threshold=-22dB:ratio=3:attack=5:release=100:makeup=2"
                ;;
            h390|rnn)
                MIC_CHAIN="highpass=f=80,lowpass=f=8000,afftdn=nr=35:nt=w,agate=threshold=-40dB:ratio=2:attack=5:release=150:makeup=4,acompressor=threshold=-24dB:ratio=3:attack=2:release=80:makeup=3,alimiter=limit=0dB:attack=5:release=50"
                ;;
            *)
                MIC_CHAIN="highpass=f=80,lowpass=f=14000,afftdn=nr=25:nt=w,agate=threshold=-42dB:ratio=3:attack=5:release=150:makeup=4,acompressor=threshold=-24dB:ratio=4:attack=2:release=80:makeup=3,alimiter=limit=0dB:attack=5:release=50"
                ;;
        esac

        MUTE_CHAIN=""
        [ "$INTRO_MUTE" = "1" ] && MUTE_CHAIN=",volume=0:enable='lte(t,${INTRO_MUTE_DUR})'"

        if [ "$AUDIO_MODE" = "mic" ]; then
            AUDIO_INPUTS=(-thread_queue_size 8192 -f pulse -ar 48000 -ac 2 -i "$MIC_DEV")
            AUDIO_FILTER="[1:a]${MIC_CHAIN}${MUTE_CHAIN}[aout_base]"
        else
            AUDIO_INPUTS=(
                -thread_queue_size 8192 -f pulse -ar 48000 -ac 2 -i "$MIC_DEV"
                -thread_queue_size 8192 -f pulse -ar 48000 -ac 2 -i "$DESKTOP_DEV"
            )
            AUDIO_FILTER="[1:a]${MIC_CHAIN}${MUTE_CHAIN}[amic];[amic][2:a]amix=inputs=2:duration=longest:weights=1 0.5[aout_base]"
        fi
        AUDIO_MAP="[aout]"
        ;;
    *)
        echo "Audio: Desktop"
        AUDIO_INPUTS=(-thread_queue_size 8192 -f pulse -ar 48000 -ac 2 -i "$DESKTOP_DEV")
        AUDIO_FILTER="[1:a]anull[aout_base]"
        AUDIO_MAP="[aout]"
        ;;
esac

# ── Build video & intro audio filter ──────────────────────────────────────────

TITLE="${STREAM_TITLE:-}"
INTRO_VID="${INTRO_VIDEO:-}"

VIDEO_FILTER=""
VIDEO_MAP="0:v"

if [ -n "$INTRO_VID" ] && [ -f "$INTRO_VID" ] && [ "$PLATFORM" != "file" ]; then
    INTRO_DUR="${INTRO_DURATION:-300}"
    RES_W="${RESOLUTION%x*}"; RES_H="${RESOLUTION#*x}"
    echo "Intro: $INTRO_VID (${INTRO_DUR}s — overlaid in stream, audio mixed)"
    # Load intro video (scaled) AND intro audio (raw)
    VIDEO_FILTER="movie='${INTRO_VID}':loop=0,setpts=PTS-STARTPTS,scale=${RES_W}:${RES_H}:force_original_aspect_ratio=decrease,pad=${RES_W}:${RES_H}:(ow-iw)/2:(oh-ih)/2,setsar=1[intro_v];amovie='${INTRO_VID}':loop=0[intro_a];[0:v][intro_v]overlay=eof_action=pass[vover]"
    VIDEO_MAP="[vover]"
    # Mix intro audio with mic/desktop; intro ends → amix continues with mic/desktop alone
    AUDIO_FILTER="${AUDIO_FILTER};[aout_base]apad[aout_pad];[aout_pad][intro_a]amix=inputs=2:duration=longest:weights=0.5 1:normalize=0[aout]"
fi

# Title overlay (on top of intro/screen)
if [ -n "$TITLE" ]; then
    printf '%s' "$TITLE" > /tmp/stream_title.txt
    TITLE_SIZE="${STREAM_TITLE_SIZE:-28}"
    echo "Title overlay: $TITLE"
    TITLE_SRC="${VIDEO_MAP}"
    VIDEO_FILTER+="${VIDEO_FILTER:+;}${TITLE_SRC}drawtext=textfile=/tmp/stream_title.txt:fontsize=${TITLE_SIZE}:fontcolor=white@0.7:x=10:y=h-th-14:box=1:boxcolor=black@0.3:boxborderw=6[vout]"
    VIDEO_MAP="[vout]"
fi

# ── Ingest URLs ───────────────────────────────────────────────────────────────

TWITCH_URL="${STREAM_TWITCH_URL:-rtmp://live.twitch.tv/app}"
YOUTUBE_URL="${STREAM_YOUTUBE_URL:-rtmp://a.rtmp.youtube.com/live2}"

# ── Platform ──────────────────────────────────────────────────────────────────

case "$PLATFORM" in
    twitch)       echo "Mode: LIVE → Twitch" ;;
    twitch-test)  echo "Mode: TEST → Twitch" ;;
    youtube)      echo "Mode: LIVE → YouTube" ;;
    rtmp)         echo "Mode: RTMP → $KEY" ;;
    file)         echo "Mode: FILE → $KEY" ;;
    *)            usage ;;
esac
echo "Resolution: $RESOLUTION  |  Press Ctrl+C to stop."
echo "$PLATFORM LIVE $(date +%H:%M:%S)" > /tmp/stream.status

# ── Encoding params ───────────────────────────────────────────────────────────

FPS="${STREAM_FPS:-30}"
FILE_FPS="${STREAM_FILE_FPS:-60}"
PRESET="${STREAM_PRESET:-veryfast}"
GOP="${STREAM_GOP:-120}"
VIDEO_BITRATE="${STREAM_VIDEO_BITRATE:-2500k}"
MAXRATE="${STREAM_MAXRATE:-3000k}"
BUFSIZE="${STREAM_BUFSIZE:-5000k}"
AUDIO_BITRATE="${STREAM_AUDIO_BITRATE:-160k}"
FILE_AUDIO_BITRATE="${STREAM_FILE_AUDIO_BITRATE:-320k}"

# x264 extra flags
X264_OPTS=""
[ -n "${STREAM_PROFILE:-}" ] && X264_OPTS="$X264_OPTS -profile:v ${STREAM_PROFILE}"
[ -n "${STREAM_TUNE:-}" ]   && X264_OPTS="$X264_OPTS -tune ${STREAM_TUNE}"

FILTER="${VIDEO_FILTER}${VIDEO_FILTER:+;}$AUDIO_FILTER"

# ── Run ───────────────────────────────────────────────────────────────────────

if [ "$PLATFORM" = "file" ]; then
    exec ffmpeg -hide_banner -loglevel info -stats \
        -thread_queue_size 8192 \
        -f x11grab -framerate "$FILE_FPS" -video_size "$RESOLUTION" -i "$DISPLAY_VAL" \
        "${AUDIO_INPUTS[@]}" \
        -filter_complex "$FILTER" \
        -map "$VIDEO_MAP" -map "$AUDIO_MAP" \
        -c:v libx264 -preset "$PRESET" -crf 20 -pix_fmt yuv420p \
        -c:a libopus -b:a "$FILE_AUDIO_BITRATE" -application audio -vbr on -compression_level 10 \
        "$KEY"
else
    case "$PLATFORM" in
        twitch)       URL="$TWITCH_URL/$KEY" ;;
        twitch-test)  URL="$TWITCH_URL/$KEY?bandwidthtest=true" ;;
        youtube)      URL="$YOUTUBE_URL/$KEY" ;;
        rtmp)         URL="$KEY" ;;
    esac
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
        -f flv -flvflags no_duration_filesize \
        "$URL"
fi
