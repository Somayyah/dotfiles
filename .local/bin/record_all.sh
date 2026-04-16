#!/usr/bin/env bash

name="$1"

if [ -z "$name" ]; then
  name="REC_$(date +%F_%H-%M-%S)"
fi

base="${name%.*}"

# pre-buffer PulseAudio properly
ffmpeg -f pulse -thread_queue_size 1024 -i default -t 1 -f null - 2>/dev/null

nohup ffmpeg -hide_banner \
  -loglevel info \
  -stats \
  -f x11grab \
  -video_size "$(xdpyinfo | awk '/dimensions/{print $2}')" \
  -i "$DISPLAY" \
  -f pulse -thread_queue_size 1024 -i default \
  -c:v libx264 -preset veryfast -crf 23 \
  -c:a libopus \
  "${base}.mkv" \
  > /tmp/ffmpeg.log 2>&1 &

pgrep -n ffmpeg > /tmp/ffmpeg.pid

notify-send "Recording started" "${base}.mkv"
