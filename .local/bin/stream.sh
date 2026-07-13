#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") <platform> <stream-key-or-path>"
    echo ""
    echo "Platforms:"
    echo "  twitch         rtmp://live.twitch.tv/app/<key>"
    echo "  twitch-test    Twitch bandwidth test (NOT live)"
    echo "  youtube        rtmp://a.rtmp.youtube.com/live2/<key>"
    echo "  rtmp <url>     Custom RTMP URL"
    echo "  file <path>    Save to local file for testing"
    echo ""
    echo "Audio tunables (env vars):"
    echo "  BANDPASS     default: highpass=f=80,lowpass=f=18000"
    echo "  NR           afftdn noise reduction (default: 25)"
    echo "  GATE_THR     agate threshold (default: -35dB)"
    echo "  COMP_THR     compressor threshold (default: -22dB)"
    echo "  DESKTOP_VOL  desktop audio mix weight (default: 0.5)"
    exit 1
}

[ $# -ge 2 ] || usage

PLATFORM="$1"
KEY="$2"

RESOLUTION=$(xdpyinfo | awk '/dimensions/{print $2}')
DISPLAY_VAL="${DISPLAY:-:0}"
MIC="alsa_input.pci-0000_00_1f.3.analog-stereo"
DESKTOP="alsa_output.pci-0000_00_1f.3.analog-stereo.monitor"

BANDPASS="${BANDPASS:-highpass=f=80,lowpass=f=18000}"
NR="${NR:-25}"
GATE_THR="${GATE_THR:--35dB}"
COMP_THR="${COMP_THR:--22dB}"
DESKTOP_VOL="${DESKTOP_VOL:-0.5}"

# Warm up mic (wakes from SUSPENDED state)
ffmpeg -f pulse -ar 48000 -i "$MIC" -t 1 -f null - 2>/dev/null || true
sleep 1

echo "Screen: $RESOLUTION  |  Mic + Desktop audio"
case "$PLATFORM" in
    twitch)       echo "Mode: LIVE → Twitch" ;;
    twitch-test)  echo "Mode: TEST → Twitch (bandwidth test, not public)" ;;
    youtube)      echo "Mode: LIVE → YouTube" ;;
    rtmp)         echo "Mode: RTMP → $KEY" ;;
    file)         echo "Mode: FILE → $KEY" ;;
    *)            usage ;;
esac
echo "Press Ctrl+C to stop."

AUDIO_FILTER="
    [1:a]$BANDPASS,
         afftdn=nr=$NR:nt=w:bn=0,
         anlmdn=s=0.0001,
         agate=threshold=$GATE_THR:attack=5:release=150:range=0,
         acompressor=threshold=$COMP_THR:ratio=3:attack=5:release=80:makeup=2[amic];
    [amic][2:a]amix=inputs=2:duration=longest:weights=1 $DESKTOP_VOL[aout]"

if [ "$PLATFORM" = "file" ]; then
    exec ffmpeg -hide_banner -loglevel info -stats \
        -thread_queue_size 8192 \
        -f x11grab -framerate 30 -video_size "$RESOLUTION" -i "$DISPLAY_VAL" \
        -thread_queue_size 8192 \
        -f pulse -ar 48000 -ac 2 -i "$MIC" \
        -thread_queue_size 8192 \
        -f pulse -ar 48000 -ac 2 -i "$DESKTOP" \
        -filter_complex "$AUDIO_FILTER" \
        -map 0:v -map "[aout]" \
        -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p \
        -c:a aac -b:a 160k -ar 48000 \
        "$KEY"
else
    case "$PLATFORM" in
        twitch)       URL="rtmp://live.twitch.tv/app/$KEY" ;;
        twitch-test)  URL="rtmp://live.twitch.tv/app/$KEY?bandwidthtest=true" ;;
        youtube)      URL="rtmp://a.rtmp.youtube.com/live2/$KEY" ;;
        rtmp)         URL="$KEY" ;;
    esac
    exec ffmpeg -hide_banner -loglevel info -stats \
        -thread_queue_size 8192 \
        -f x11grab -framerate 30 -video_size "$RESOLUTION" -i "$DISPLAY_VAL" \
        -thread_queue_size 8192 \
        -f pulse -ar 48000 -ac 2 -i "$MIC" \
        -thread_queue_size 8192 \
        -f pulse -ar 48000 -ac 2 -i "$DESKTOP" \
        -filter_complex "$AUDIO_FILTER" \
        -map 0:v -map "[aout]" \
        -c:v libx264 -preset veryfast -b:v 2500k -maxrate 3000k -bufsize 5000k \
        -pix_fmt yuv420p -g 120 \
        -c:a aac -b:a 160k -ar 48000 \
        -f flv -flvflags no_duration_filesize \
        "$URL"
fi
