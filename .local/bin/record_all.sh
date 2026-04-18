#!/usr/bin/env bash

name="${1:-REC_$(date +%F_%H-%M-%S)}"
base="${name%.*}"

# Segment index passed as second arg (default 1)
seg="${2:-1}"
outfile="$HOME/${base}_seg${seg}.mkv"

RESOLUTION=$(xdpyinfo | awk '/dimensions/{print $2}')
DISPLAY_VAL="${DISPLAY:-:0}"
MIC="alsa_input.pci-0000_00_1f.3.analog-stereo"
MONITOR="alsa_output.pci-0000_00_1f.3.analog-stereo.monitor"

ffmpeg -f pulse -ar 48000 -i "$MIC"     -t 1 -f null - 2>/dev/null || true
ffmpeg -f pulse -ar 48000 -i "$MONITOR" -t 1 -f null - 2>/dev/null || true
sleep 1

nohup ffmpeg -hide_banner \
  -loglevel info \
  -stats \
  \
  -thread_queue_size 8192 \
  -f x11grab \
  -framerate 60 \
  -video_size "$RESOLUTION" \
  -i "$DISPLAY_VAL" \
  \
  -thread_queue_size 8192 \
  -f pulse \
  -ar 48000 \
  -ac 2 \
  -i "$MIC" \
  \
  -thread_queue_size 8192 \
  -f pulse \
  -ar 48000 \
  -ac 2 \
  -i "$MONITOR" \
  \
  -filter_complex "
    [1:a]highpass=f=80,
         lowpass=f=18000,
         anlmdn=s=0.002:p=0.002:r=0.002,
         acompressor=threshold=-22dB:ratio=3:attack=5:release=80:makeup=2[mic];
    [2:a]highpass=f=40[desk];
    [mic][desk]amix=inputs=2:duration=first:dropout_transition=0:weights='1.5 1',
               aresample=resampler=soxr:precision=33[aout]
  " \
  -map 0:v \
  -map "[aout]" \
  \
  -c:v libx264 \
  -preset veryfast \
  -crf 20 \
  -pix_fmt yuv420p \
  \
  -c:a libopus \
  -b:a 320k \
  -application audio \
  -vbr on \
  -compression_level 10 \
  \
  "$outfile" \
  > /tmp/ffmpeg.log 2>&1 &

PID=$!
sleep 0.5

if kill -0 "$PID" 2>/dev/null; then
    echo "$PID"  > /tmp/ffmpeg.pid
    echo "running" > /tmp/ffmpeg.state
    # Append this segment path to the session's segment list
    echo "$outfile" >> /tmp/ffmpeg.segments
    notify-send "Recording" "Segment $seg → $outfile"
else
    notify-send "Recording FAILED" "Check /tmp/ffmpeg.log"
fi
