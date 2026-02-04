#!/usr/bin/env bash

set -euo pipefail
# Prevent "*.mp4" becoming a literal string if no matches.
shopt -s nullglob

# --- Resolve repo root (script location), not the caller's cwd ---
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# --- Args: input directory + optional smoke mode ---
INPUT_DIR=""
SMOKE=0

usage() {
  echo "Usage:"
  echo "  ./run.sh --input /path/to/videos [--smoke]"
  echo "  ./run.sh /path/to/videos [--smoke]"
  echo "If omitted, defaults to: $ROOT_DIR/samples/videos"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input|-i)
      INPUT_DIR="${2:-}"
      shift 2
      ;;
    --smoke)
      SMOKE=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      # First non-flag argument is treated as input directory.
      if [[ -z "$INPUT_DIR" ]]; then
        INPUT_DIR="$1"
        shift
      else
        echo "Unknown argument: $1"
        usage
      fi
      ;;
  esac
done

# Default input dir if none provided (useful for demo samples later).
if [[ -z "$INPUT_DIR" ]]; then
  INPUT_DIR="$ROOT_DIR/samples/videos"
fi

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Input directory not found: $INPUT_DIR"
  usage
fi

# Normalize to absolute path (prevents confusion if caller uses relative paths).
INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"

# --- Standard project folders ---
WORK_DIR="$ROOT_DIR/work"
OUTPUT_DIR="$ROOT_DIR/output"

# Pipeline folders (all under work/ to keep repo tidy)
EXTRACTED_FRAMES_DIR="$WORK_DIR/extracted_frames"
RESIZED_FRAMES_DIR="$WORK_DIR/resized_frames"
EXCLUDED_FRAMES_DIR="$WORK_DIR/excluded_frames"

FINAL_VIDEO="$OUTPUT_DIR/final_video.mp4"

mkdir -p "$EXTRACTED_FRAMES_DIR" "$RESIZED_FRAMES_DIR" "$EXCLUDED_FRAMES_DIR" "$OUTPUT_DIR"

# --- Optional: quick dependency check (recommended to add soon) ---
# If you already created doctor.sh, uncomment:
# bash "$ROOT_DIR/doctor.sh"

echo "=== Video pipeline ==="
echo "Input directory: $INPUT_DIR"
echo "Work directory:  $WORK_DIR"
echo "Output video:    $FINAL_VIDEO"
echo "Smoke mode:      $SMOKE"
echo

# --- Step 1: Extract frames from videos in INPUT_DIR ---
# Contract: INPUT_DIR, OUT_DIR, FPS_FILTER
export INPUT_DIR="$INPUT_DIR"
export OUT_DIR="$EXTRACTED_FRAMES_DIR"

# In smoke mode, extract fewer frames by lowering sampling (or you can limit time later).
# Your extract step expects FPS_FILTER like "1/2".
if [[ "$SMOKE" -eq 1 ]]; then
  export FPS_FILTER="1/2"      # one frame every 2 seconds (fast demo)
else
  export FPS_FILTER="10"      # keep as your chosen default for now
fi

bash "$ROOT_DIR/steps/1-extract_frames.sh"

# --- Step 2: Resize/crop extracted frames ---
# Contract: IN_DIR, OUT_DIR, SCALE_FILTER, CROP_FILTER
export IN_DIR="$EXTRACTED_FRAMES_DIR"
export OUT_DIR="$RESIZED_FRAMES_DIR"
export SCALE_FILTER="1620:-1"
export CROP_FILTER="1280:720:170:0"

bash "$ROOT_DIR/steps/2-resize_images.sh" "$EXTRACTED_FRAMES_DIR" "$RESIZED_FRAMES_DIR" "$SCALE_FILTER" "$CROP_FILTER"

# --- Step 3: OCR pass to exclude frames with text/logos ---
# Pass 1 (PSM 11), confidence threshold 75, minimum letters 1
python3 "$ROOT_DIR/steps/3-delete_text.py" \
  --input "$WORK_DIR/resized_frames" \
  --excluded "$WORK_DIR/excluded_frames" \
  --min-conf 75 \
  --min-letters 1 \
  --tess-config "--psm 11 --oem 3 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

# Pass 2 (PSM 3), confidence threshold 58, min letters 1
python3 "$ROOT_DIR/steps/3-delete_text.py" \
  --input "$WORK_DIR/resized_frames" \
  --excluded "$WORK_DIR/excluded_frames" \
  --min-conf 58 \
  --min-letters 1 \
  --tess-config "--psm 3 --oem 3 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"


# --- Step 4: Randomize + rename sequentially for encoding ---
# IMPORTANT: This operates on the folder that will be encoded.
# After step 3, "kept" frames are those still remaining in RESIZED_FRAMES_DIR.
# Contract: FRAMES_DIR
export FRAMES_DIR="$RESIZED_FRAMES_DIR"
bash "$ROOT_DIR/steps/4-randomize_order.sh" "$RESIZED_FRAMES_DIR"

# --- Step 5: Convert sequential frames to final video ---
# Contract: FRAMES_DIR, OUT_VIDEO, FPS, CRF, PRESET
export FRAMES_DIR="$RESIZED_FRAMES_DIR"
export OUT_VIDEO="$FINAL_VIDEO"

# Keep these configurable, but provide sane defaults:
export FPS="60"
export CRF="18"
export PRESET="veryslow"

# In smoke mode you can also raise CRF and lower FPS for speed:
if [[ "$SMOKE" -eq 1 ]]; then
  export FPS="30"
  export CRF="28"
  export PRESET="fast"
fi

bash "$ROOT_DIR/steps/5-convert_frames_to_video.sh" \
  "$RESIZED_FRAMES_DIR" \
  "$OUT_VIDEO" \
  "$FPS" \
  "$CRF" \
  "$PRESET"

echo
echo "✅ Done!"
echo "Final video: $FINAL_VIDEO"
echo "Excluded frames: $EXCLUDED_FRAMES_DIR"
