#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage:"
  echo "  ./run.sh <input_dir> <output_dir> [--smoke] [--work-dir <dir>]"
  echo "  ./run.sh --input <input_dir> --output <output_dir> [--smoke] [--work-dir <dir>]"
  exit 1
}

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

INPUT_DIR=""
OUTPUT_DIR=""
WORK_DIR=""
SMOKE=0

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input|-i)
      INPUT_DIR="${2:-}"; shift 2 ;;
    --output|-o)
      OUTPUT_DIR="${2:-}"; shift 2 ;;
    --work-dir)
      WORK_DIR="${2:-}"; shift 2 ;;
    --smoke)
      SMOKE=1; shift ;;
    -h|--help)
      usage ;;
    *)
      if [[ -z "$INPUT_DIR" ]]; then
        INPUT_DIR="$1"; shift
      elif [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="$1"; shift
      else
        echo "Unknown argument: $1"
        usage
      fi
      ;;
  esac
done

# Defaults (useful for demos)
if [[ -z "$INPUT_DIR" ]]; then
  INPUT_DIR="$ROOT_DIR/samples/videos"
fi
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$ROOT_DIR/output"
fi
if [[ -z "$WORK_DIR" ]]; then
  WORK_DIR="$ROOT_DIR/work"
fi

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Input directory not found: $INPUT_DIR"
  usage
fi

# Normalize
INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"
mkdir -p "$OUTPUT_DIR" "$WORK_DIR"

# If OUTPUT_DIR is relative, anchor it at repo root for consistency
if [[ "$OUTPUT_DIR" != /* ]]; then
  OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

# --- Standard project folders ---
EXTRACTED_FRAMES_DIR="$WORK_DIR/extracted_frames"
RESIZED_FRAMES_DIR="$WORK_DIR/resized_frames"
EXCLUDED_FRAMES_DIR="$WORK_DIR/excluded_frames"
FINAL_VIDEO="$OUTPUT_DIR/final_video.mp4"

mkdir -p "$EXTRACTED_FRAMES_DIR" "$RESIZED_FRAMES_DIR" "$EXCLUDED_FRAMES_DIR"

echo "=== Video pipeline ==="
echo "Input directory: $INPUT_DIR"
echo "Work directory:  $WORK_DIR"
echo "Output video:    $FINAL_VIDEO"
echo "Smoke mode:      $SMOKE"
echo

# --- Step 1: Extract frames ---
export INPUT_DIR="$INPUT_DIR"
export OUT_DIR="$EXTRACTED_FRAMES_DIR"

if [[ "$SMOKE" -eq 1 ]]; then
  export FPS_FILTER="1/2"
else
  export FPS_FILTER="10"
fi

bash "$ROOT_DIR/steps/1-extract_frames.sh"

# --- Step 2: Resize/crop ---
export IN_DIR="$EXTRACTED_FRAMES_DIR"
export OUT_DIR="$RESIZED_FRAMES_DIR"
export SCALE_FILTER="1620:-1"
export CROP_FILTER="1280:720:170:0"

bash "$ROOT_DIR/steps/2-resize_images.sh" \
  "$EXTRACTED_FRAMES_DIR" \
  "$RESIZED_FRAMES_DIR" \
  "$SCALE_FILTER" \
  "$CROP_FILTER"

# DELETE ALL EXTRACTED FRAMES
# After resize/crop succeeds, raw extracted frames are no longer needed
rm -rf "$EXTRACTED_FRAMES_DIR"

# --- Step 3: OCR exclude ---
python3 "$ROOT_DIR/steps/3-delete_text.py" \
  --input "$RESIZED_FRAMES_DIR" \
  --excluded "$EXCLUDED_FRAMES_DIR" \
  --min-conf 75 \
  --min-letters 1 \
  --tess-config "--psm 11 --oem 3 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

python3 "$ROOT_DIR/steps/3-delete_text.py" \
  --input "$RESIZED_FRAMES_DIR" \
  --excluded "$EXCLUDED_FRAMES_DIR" \
  --min-conf 58 \
  --min-letters 1 \
  --tess-config "--psm 3 --oem 3 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

# --- Step 4: Randomize ---
bash "$ROOT_DIR/steps/4-randomize_order.sh" "$RESIZED_FRAMES_DIR"

# --- Step 5: Encode video ---
export FRAMES_DIR="$RESIZED_FRAMES_DIR"
export OUT_VIDEO="$FINAL_VIDEO"

export FPS="60"
export CRF="18"
export PRESET="veryslow"

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
