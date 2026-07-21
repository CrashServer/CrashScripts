#!/usr/bin/env bash
#
# instagram.sh — re-encode a video into an Instagram-compatible MP4.
#
# Fixes the common causes of Instagram's silent "unknown error":
#   - full-range yuvj420p pixel format  -> standard yuv420p / limited (tv) range
#   - very high bitrate / huge file      -> capped bitrate, smaller file
#   - 60fps and other odd frame rates    -> 30fps
#   - moov atom at end of file           -> +faststart (metadata moved to front)
# The aspect ratio and resolution are left unchanged.
#
# Usage:
#   ./instagram.sh input.mp4                 # -> input_instagram.mp4
#   ./instagram.sh input.mp4 output.mp4      # explicit output name
#   ./instagram.sh *.mp4                      # batch: each -> <name>_instagram.mp4
#
set -euo pipefail

# --- tunables (override via environment, e.g. FPS=60 ./instagram.sh in.mp4) ---
FPS="${FPS:-30}"          # target frame rate (Instagram feed: 30)
VBITRATE="${VBITRATE:-8M}"   # target video bitrate
MAXRATE="${MAXRATE:-10M}"    # peak video bitrate
BUFSIZE="${BUFSIZE:-12M}"    # rate-control buffer
ABITRATE="${ABITRATE:-128k}" # audio bitrate

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "error: ffmpeg is not installed or not on PATH." >&2
  exit 1
fi

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <input> [output]" >&2
  echo "       $0 <input1> <input2> ...   (batch mode)" >&2
  exit 2
fi

encode() {
  local in="$1" out="$2"
  if [ ! -f "$in" ]; then
    echo "skip: '$in' is not a file" >&2
    return 1
  fi
  echo ">> $in -> $out"
  ffmpeg -y -i "$in" \
    -vf "scale=in_range=full:out_range=tv,format=yuv420p" \
    -r "$FPS" -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p \
    -b:v "$VBITRATE" -maxrate "$MAXRATE" -bufsize "$BUFSIZE" \
    -color_range tv -colorspace bt709 -color_primaries bt709 -color_trc bt709 \
    -c:a aac -b:a "$ABITRATE" -ar 44100 \
    -movflags +faststart \
    "$out" </dev/null
  echo ">> done: $out ($(du -h "$out" | cut -f1))"
}

# Two args where the second is NOT an existing video -> explicit output name.
if [ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -e "$2" ]; then
  encode "$1" "$2"
  exit 0
fi

# Otherwise treat every argument as an input and derive its output name.
status=0
for in in "$@"; do
  dir=$(dirname "$in")
  base=$(basename "$in")
  name="${base%.*}"
  out="$dir/${name}_instagram.mp4"
  encode "$in" "$out" || status=1
done
exit "$status"
