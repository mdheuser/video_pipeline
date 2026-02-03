#!/usr/bin/env bash

# Fail fast
set -euo pipefail
shopt -s nullglob

# Require INPUT_DIR and OUT_DIR to be provided (either env vars or by run.sh)
: "${INPUT_DIR:?INPUT_DIR is not set}"
: "${OUT_DIR:?OUT_DIR is not set}"

# Quote paths and avoid cd side effects by using full paths
mkdir -p "$OUT_DIR"

# Build an explicit list of matching videos, and error clearly if none
VIDEOS=( "$INPUT_DIR"/*.MOV "$INPUT_DIR"/*.mov "$INPUT_DIR"/*.avi "$INPUT_DIR"/*.mp4 "$INPUT_DIR"/*.mkv )
if [[ ${#VIDEOS[@]} -eq 0 ]]; then
  echo "No videos found in: $INPUT_DIR (expected .mov .avi .mp4 .mkv)"
  exit 1
fi

# Allow FPS to be configured from env (default matches the current fps=1/2)
FPS_FILTER="${FPS_FILTER:-1/2}"

for video in "${VIDEOS[@]}"; do
  base="$(basename "${video%.*}")"
  ffmpeg -i "$video" -vf "fps=$FPS_FILTER" "$OUT_DIR/${base}_frame_%09d.jpg"
done
