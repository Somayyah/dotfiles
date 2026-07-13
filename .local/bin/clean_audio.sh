#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") <input> [output]"
    echo ""
    echo "Post-processes screen recording audio for cleaner female vocals:"
    echo "  Bandpass    150Hz–8kHz  (cuts rumble and hiss outside vocal range)"
    echo "  afftdn      FFT denoise (removes static/hiss)"
    echo "  anlmdn      NL-means    (removes residual/metallic artifacts)"
    echo "  agate       Noise gate  (cuts background noise between words)"
    echo "  acompressor             (evens out vocal levels)"
    exit 1
}

[ $# -ge 1 ] || usage

input="$1"
output="${2:-${input%.*}_clean.${input##*.}}"

[ -f "$input" ] || { echo "Input file not found: $input"; exit 1; }

bandpass="${BANDPASS:-highpass=f=150,lowpass=f=8000}"
nr="${NR:-15}"
gate_thr="${GATE_THR:--35dB}"
comp_thr="${COMP_THR:--24dB}"

ffmpeg -hide_banner -loglevel info -stats \
  -i "$input" \
  -filter_complex "
    [0:a]$bandpass,
         afftdn=nr=$nr:nt=w:bn=0,
         anlmdn=s=0.0001,
          agate=threshold=$gate_thr:attack=5:release=150:range=0,
         acompressor=threshold=$comp_thr:ratio=4:attack=5:release=50:makeup=4[aout]
  " \
  -map 0:v? -c:v copy \
  -map "[aout]" \
  -c:a libopus -b:a 320k -application audio -vbr on -compression_level 10 \
  "$output"

echo "Done → $output"
