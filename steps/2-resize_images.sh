#!/usr/bin/env bash
# Resize + crop extracted frames into a new folder.
# Usage:
#   bash steps/2-resize_images.sh <input_frames_dir> <output_frames_dir> [scale_filter] [crop_filter]
#
# Example:
#   bash steps/2-resize_images.sh work/extracted_frames work/resized_frames "1620:-1" "1280:720:170:0"

set -euo pipefail
shopt -s nullglob

INPUT_FRAMES_DIR="${1:-}"
OUTPUT_FRAMES_DIR="${2:-}"

# Defaults match your current pipeline.
SCALE_FILTER="${3:-1620:-1}"
CROP_FILTER="${4:-1280:720:170:0}"

if [[ -z "$INPUT_FRAMES_DIR" || -z "$OUTPUT_FRAMES_DIR" ]]; then
  echo "Usage: $0 <input_frames_dir> <output_frames_dir> [scale_filter] [crop_filter]"
  exit 1
fi

if [[ ! -d "$INPUT_FRAMES_DIR" ]]; then
  echo "Input frames directory not found: $INPUT_FRAMES_DIR"
  exit 1
fi

mkdir -p "$OUTPUT_FRAMES_DIR"

IMAGES=( "$INPUT_FRAMES_DIR"/*.jpg )
if [[ ${#IMAGES[@]} -eq 0 ]]; then
  echo "No .jpg frames found in: $INPUT_FRAMES_DIR"
  exit 1
fi

echo "Resizing and cropping frames..."
echo "  Input:  $INPUT_FRAMES_DIR"
echo "  Output: $OUTPUT_FRAMES_DIR"
echo "  Scale:  $SCALE_FILTER"
echo "  Crop:   $CROP_FILTER"

for img in "${IMAGES[@]}"; do
  ffmpeg -y -i "$img" -vf "scale=$SCALE_FILTER,crop=$CROP_FILTER" \
    "$OUTPUT_FRAMES_DIR/$(basename "$img")"
done

echo "✅ Done. Wrote resized frames to: $OUTPUT_FRAMES_DIR"
