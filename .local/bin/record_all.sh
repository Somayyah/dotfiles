#!/usr/bin/env bash

name="$1"

if [ -z "$name" ]; then
  name="REC_$(date +%F_%H-%M-%S)"
fi

base="${name%.*}"
outfile="${base}.mkv"

ffmpeg -f pulse -thread_queue_size 4096 -i default -t 1 -f null - 2>/dev/null

sleep 1

nohup ffmpeg -hide_banner \
  -loglevel info \
  -stats \
  -use_wallclock_as_timestamps 1 \
  -vsync 1 \
  -async 1 \
  -thread_queue_size 4096 \
  -f x11grab \
  -framerate 60 \
  -video_size "$(xdpyinfo | awk '/dimensions/{print $2}')" \
  -i "$DISPLAY" \
  -f pulse \
  -i default \
  -c:v libx264 \
  -preset veryfast \
  -crf 23 \
  -pix_fmt yuv420p \
  -c:a libopus \
  -af "aresample=async=1:first_pts=0" \
  "$outfile" \
  > /tmp/ffmpeg.log 2>&1 &

PID=$!
echo "$PID" > /tmp/ffmpeg.pid

notify-send "Recording started" "$outfile"
