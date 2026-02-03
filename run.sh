#!/usr/bin/env bash

# safer bash defaults. Exits on error/undefined var, catches pipeline errors.
set -euo pipefail

# make globs that match nothing expand to nothing (prevents "*.mp4" being treated as a literal filename).
shopt -s nullglob

# base directory is now the script location (repo root), NOT pwd.
# This means the script works even if someone runs it from another directory.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# --------------------------------------------------------------------
# input directory handling
# - User can pass input dir as:
#     ./run.sh --input /path/to/videos
#     ./run.sh /path/to/videos
# - If omitted, defaults to ./input (repo-local).
# --------------------------------------------------------------------
INPUT_DIR=""
SMOKE=0

usage() {
  echo "Usage:"
  echo "  ./run.sh --input /path/to/videos [--smoke]"
  echo "  ./run.sh /path/to/videos [--smoke]"
  echo "If omitted, defaults to: $ROOT_DIR/input"
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
      # first non-flag argument is treated as INPUT_DIR
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

if [[ -z "$INPUT_DIR" ]]; then
  INPUT_DIR="$ROOT_DIR/input"
fi

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Input directory not found: $INPUT_DIR"
  usage
fi

# resolve INPUT_DIR to an absolute path (prevents path confusion later).
INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"

# --------------------------------------------------------------------
# standard work/output locations inside the repo (relative paths)
# This makes the project tidy and predictable.
# --------------------------------------------------------------------
WORK_DIR="$ROOT_DIR/work"
OUT_DIR="$ROOT_DIR/output"

FRAMES_FOLDER="$WORK_DIR/extracted_frames"
RESIZED_FOLDER="$WORK_DIR/resized_frames"

# Excluded images are kept just to check if Tesseract is working correctly.
# False positives are expected and much better than false negatives.
# (Text will be detected in frames without any text)
EXCLUDED_FOLDER="$WORK_DIR/excluded_frames" 

FINAL_VIDEO="$OUT_DIR/final_video.mp4"

# python script path is repo-relative
PYTHON_SCRIPT="$ROOT_DIR/steps/3-delete_text.py"

# Create necessary folders
mkdir -p "$FRAMES_FOLDER" "$RESIZED_FOLDER" "$EXCLUDED_FOLDER" "$OUT_DIR"

# --------------------------------------------------------------------
# Optional "smoke" mode for quick runs (recruiter-friendly).
# When --smoke is enabled, we limit how much video each file contributes.
# You can tune this later (seconds, fps, number of videos, etc.).
# --------------------------------------------------------------------
EXTRACT_LIMIT_ARGS=()
if [[ "$SMOKE" -eq 1 ]]; then
  EXTRACT_LIMIT_ARGS=( -t 5 )   # only first 5 seconds per input video
fi

# --------------------------------------------------------------------
# 1 - Extract frames from videos
# we now read videos from INPUT_DIR, not from the current directory.
# robust check for "no video files found".
# --------------------------------------------------------------------
echo "Extracting frames from: $INPUT_DIR"

VIDEOS=( "$INPUT_DIR"/*.avi "$INPUT_DIR"/*.mp4 "$INPUT_DIR"/*.mkv )
if [[ ${#VIDEOS[@]} -eq 0 ]]; then
  echo "No videos found in $INPUT_DIR (expected .avi .mp4 .mkv)."
  exit 1
fi

# Note: backgrounding ffmpeg per video can spawn many processes if there are lots of files.
# Keeping your approach, but be aware this can stress CPU/disk on big batches.
for video in "${VIDEOS[@]}"; do
  base="$(basename "${video%.*}")"
  ffmpeg "${EXTRACT_LIMIT_ARGS[@]}" -i "$video" -vf fps=1 \
    "$FRAMES_FOLDER/${base}_frame_%09d.jpg" &
done
wait

# --------------------------------------------------------------------
# 2 - Resize and crop frames to 16:9
# output goes to RESIZED_FOLDER inside work/
# --------------------------------------------------------------------
echo "Resizing and cropping frames..."
for img in "$FRAMES_FOLDER"/*.jpg; do
  ffmpeg -i "$img" -vf "scale=1620:-1,crop=1280:720:170:0" \
    "$RESIZED_FOLDER/$(basename "$img")"
done

# --------------------------------------------------------------------
# 3 - Remove images with text or logos (python script)
# IMPORTANT: You should update 3-delete_text.py to accept --input/--excluded
# (or read env vars) so it doesn't use hardcoded /Users/... paths.
#
# If your script DOES support args, this is the correct call:
# --------------------------------------------------------------------
python3 "$PYTHON_SCRIPT" --input "$RESIZED_FOLDER" --excluded "$EXCLUDED_FOLDER"

# If your script does NOT support args yet, temporarily comment the line above
# and fix 3-delete_text.py first (or add argparse like we discussed).

# --------------------------------------------------------------------
# 4 - Randomize file order and rename sequentially
# CRITICAL CHANGED FIX: This must operate on RESIZED_FOLDER because step 5 expects
# sequential names ("%09d.jpg") in RESIZED_FOLDER.
#
# ALSO removed uuidgen dependency (not guaranteed on every system).
# We shuffle using python (available because you're already requiring python3).
# --------------------------------------------------------------------
echo "Randomizing resized frame order and renaming sequentially..."
cd "$RESIZED_FOLDER"

TEMP_DIR="$(mktemp -d)"

# get a shuffled list of jpg files using python
mapfile -t SHUFFLED < <(python3 - <<'PY'
import glob, random
files = glob.glob("*.jpg")
random.shuffle(files)
for f in files:
    print(f)
PY
)

# Move shuffled files into temp with sequential names
counter=1
for f in "${SHUFFLED[@]}"; do
  # Skip if list is empty (defensive)
  [[ -z "$f" ]] && continue
  mv "$f" "$TEMP_DIR/$(printf "%09d.jpg" "$counter")"
  counter=$((counter + 1))
done

# Move them back
mv "$TEMP_DIR"/*.jpg .
rmdir "$TEMP_DIR"

echo "Renaming complete. Files are now named sequentially from 000000001.jpg"

# --------------------------------------------------------------------
# 5 - Convert images into video
# video is written into ./output, not hardcoded absolute path.
# --------------------------------------------------------------------
echo "Generating video..."
ffmpeg -y -framerate 60 -start_number 1 -i "%09d.jpg" \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
  "$FINAL_VIDEO"

echo "✅ Process completed! Your video is saved as: $FINAL_VIDEO"
