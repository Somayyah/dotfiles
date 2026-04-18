#!/usr/bin/env bash
PID_FILE="/tmp/ffmpeg.pid"
STATE_FILE="/tmp/ffmpeg.state"
SEGMENTS_FILE="/tmp/ffmpeg.segments"

get_ffmpeg_pid() {
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "$pid"; return 0
    fi
    pgrep -u "$USER" -f "x11grab" 2>/dev/null | head -1
}

STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "none")

if [ "$STATE" = "running" ]; then
    LIVE_PID=$(get_ffmpeg_pid)
    if [ -z "$LIVE_PID" ]; then
        notify-send "⚠ No active recording"
        exit 0
    fi
    # stop segment cleanly
    kill -INT "$LIVE_PID"
    sleep 1.5
    rm -f "$PID_FILE"
    echo "paused" > "$STATE_FILE"
    notify-send "Recording paused"

elif [ "$STATE" = "paused" ]; then
    # start next segment
    SESSION=$(cat /tmp/ffmpeg.session 2>/dev/null || echo "REC_$(date +%F_%H-%M-%S)")
    seg_count=$(wc -l < "$SEGMENTS_FILE" 2>/dev/null || echo 0)
    next_seg=$((seg_count + 1))
    ~/.local/bin/record_all.sh "$SESSION" "$next_seg"
    notify-send "Recording resumed" "Segment $next_seg"

else
    notify-send "No active recording"
fi
