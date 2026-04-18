#!/usr/bin/env bash
PID_FILE="/tmp/ffmpeg.pid"
SEGMENTS_FILE="/tmp/ffmpeg.segments"

get_ffmpeg_pid() {
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "$pid"; return 0
    fi
    pgrep -u "$USER" -f "x11grab" 2>/dev/null | head -1
}

LIVE_PID=$(get_ffmpeg_pid)

if [ -n "$LIVE_PID" ]; then
    kill -INT "$LIVE_PID"
    sleep 1.5
    rm -f "$PID_FILE" /tmp/ffmpeg.state

    seg_count=$(wc -l < "$SEGMENTS_FILE" 2>/dev/null || echo 0)

    if [ "$seg_count" -gt 1 ]; then
        concat_list="/tmp/ffmpeg_concat.txt"
        : > "$concat_list"
        while IFS= read -r seg; do
            echo "file '$seg'" >> "$concat_list"
        done < "$SEGMENTS_FILE"

        first_seg=$(head -1 "$SEGMENTS_FILE")
        # strip _seg1.mkv suffix to get final name
        final="${first_seg/_seg1.mkv/.mkv}"

        notify-send "⏳ Merging ${seg_count} segments..." "$final"

        if ffmpeg -hide_banner -loglevel error \
            -f concat -safe 0 -i "$concat_list" \
            -c copy "$final"; then
            while IFS= read -r seg; do rm -f "$seg"; done < "$SEGMENTS_FILE"
            notify-send "⏹ Recording saved" "$final"
        else
            notify-send "Merge FAILED" "Segments kept — check /tmp/ffmpeg_concat.txt"
        fi
    else
        first_seg=$(head -1 "$SEGMENTS_FILE")
        final="${first_seg/_seg1.mkv/.mkv}"
        mv "$first_seg" "$final"
        notify-send "⏹ Recording saved" "$final"
    fi

    rm -f "$SEGMENTS_FILE" /tmp/ffmpeg_concat.txt /tmp/ffmpeg.session

else
    rm -f "$PID_FILE" /tmp/ffmpeg.state "$SEGMENTS_FILE"
    SESSION="REC_$(date +%F_%H-%M-%S)"
    echo "$SESSION" > /tmp/ffmpeg.session
    ~/.local/bin/record_all.sh "$SESSION" 1
fi
