#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

FRAMES_DIR="${1:-}"
OUT_VIDEO="${2:-}"
FPS="${3:-60}"
CRF="${4:-18}"
PRESET="${5:-veryslow}"

if [[ -z "$FRAMES_DIR" || -z "$OUT_VIDEO" ]]; then
  echo "Usage: $0 <frames_dir> <out_video> [fps] [crf] [preset]"
  exit 1
fi

if [[ ! -d "$FRAMES_DIR" ]]; then
  echo "Frames directory not found: $FRAMES_DIR"
  exit 1
fi

mkdir -p "$(dirname "$OUT_VIDEO")"

cd "$FRAMES_DIR"

# Ensure there are jpgs
if ! ls *.jpg >/dev/null 2>&1; then
  echo "No .jpg files found in: $FRAMES_DIR"
  exit 1
fi

echo "Generating video..."
echo "  Frames:  $FRAMES_DIR"
echo "  Output:  $OUT_VIDEO"
echo "  FPS:     $FPS"
echo "  CRF:     $CRF"
echo "  Preset:  $PRESET"

# Assumes step 4 renamed frames to 000000001.jpg, 000000002.jpg, ...
ffmpeg -y -framerate "$FPS" -start_number 1 -i "%09d.jpg" \
  -c:v libx264 -preset "$PRESET" -crf "$CRF" -pix_fmt yuv420p \
  -movflags +faststart "$OUT_VIDEO"

echo "✅ Video written to: $OUT_VIDEO"
