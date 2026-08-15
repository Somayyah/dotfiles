#!/usr/bin/env bash
# Generate intro video with CRT-style countdown timer overlaid.
# Usage: generate_intro_timer.sh [source.mp4]
# Default: reads INTRO_VIDEO from ~/.config/stream.conf
# Output: $INTRO_VIDEO with "-timer" suffix (e.g. starting_soon-timer.mp4)
set -euo pipefail

CONFIG="$HOME/.config/stream.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

SRC="${1:-${INTRO_VIDEO:-$HOME/Download/src.mp4}}"
DURATION="${INTRO_DURATION:-300}"
OUT="${SRC%.mp4}-timer.mp4"
FONT="/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf"

# Output resolution = screen size (pre-scaled so stream.sh overlay is a no-op)
RESOLUTION="${STREAM_RESOLUTION:-$(xdpyinfo 2>/dev/null | awk '/dimensions/{print $2}')}"
[ -n "$RESOLUTION" ] || RESOLUTION="1366x768"
RES_W="${RESOLUTION%x*}"; RES_H="${RESOLUTION#*x}"

# Timer box measured in source video (via GIMP): top-left (194,508) bottom-right (972,850)
# These are scaled proportionally to the output resolution below.
SRC_BOX_CX=583   # center x = (194+972)/2  at source resolution
SRC_BOX_CY=679   # center y = (508+850)/2  at source resolution
FONTSIZE=200

[ -f "$SRC" ] || { echo "ERROR: source video not found: $SRC" >&2; exit 1; }
[ -f "$FONT" ] || { echo "ERROR: font not found: $FONT" >&2; exit 1; }

echo "Source:    $SRC"
echo "Duration:  ${DURATION}s"
echo "Output:    $OUT"
echo ""

# Probe source resolution and scale timer coordinates proportionally
SRC_INFO=$(ffprobe -v quiet -show_entries stream=width,height -select_streams v -of csv=p=0 "$SRC")
SRC_W="${SRC_INFO%%,*}"
SRC_H="${SRC_INFO##*,}"
if [ -z "$SRC_W" ] || [ -z "$SRC_H" ]; then
    echo "ERROR: cannot probe source video resolution" >&2
    exit 1
fi

RATIO_X=$(awk "BEGIN{printf \"%.4f\", $RES_W/$SRC_W}")
RATIO_Y=$(awk "BEGIN{printf \"%.4f\", $RES_H/$SRC_H}")
# Use the limiting ratio (same as force_original_aspect_ratio=decrease)
SCALE_RATIO=$(awk "BEGIN{print ($RATIO_X < $RATIO_Y) ? $RATIO_X : $RATIO_Y}")

BOX_X=$(awk "BEGIN{printf \"%d\", $SRC_BOX_CX * $SCALE_RATIO}")
BOX_Y=$(awk "BEGIN{printf \"%d\", $SRC_BOX_CY * $SCALE_RATIO}")
FONTSIZE=$(awk "BEGIN{printf \"%d\", $FONTSIZE * $SCALE_RATIO}")
echo "Source:    ${SRC_W}x${SRC_H} → Output: ${RES_W}x${RES_H}"
echo "Timer at:  ($BOX_X, $BOX_Y)  font=${FONTSIZE}px"
echo ""

ffmpeg -hide_banner -stream_loop -1 -i "$SRC" \
  -filter_complex "\
[0:v]scale=${RES_W}:${RES_H}:force_original_aspect_ratio=decrease,pad=${RES_W}:${RES_H}:(ow-iw)/2:(oh-ih)/2,setsar=1,drawtext=fontfile=${FONT}:\
fontsize=${FONTSIZE}:\
fontcolor=white@0.95:\
shadowcolor=black@0.6:shadowx=3:shadowy=3:\
borderw=2:bordercolor=black@0.4:\
x=${BOX_X}-tw/2+if(lt(random(1)\,0.03)\,random(6)-3\,0):\
y=${BOX_Y}-th/2+if(lt(random(1)\,0.02)\,random(4)-2\,0):\
text='%{eif\:(${DURATION}-t)/60\:d}\:%{eif\:mod(${DURATION}-t,60)\:d\:2}'\
[out]" \
  -map "[out]" -map 0:a \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k \
  -t "$DURATION" \
  -shortest \
  "$OUT"

echo ""
echo "Done → $OUT"
echo "Output resolution: ${RES_W}x${RES_H} (matches screen — minimal CPU at stream time)"
echo "Update ~/.config/stream.conf:  INTRO_VIDEO=\"$OUT\""
