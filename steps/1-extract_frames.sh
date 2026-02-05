#!/usr/bin/env bash

# Fail fast
set -euo pipefail
shopt -s nullglob

# Require INPUT_DIR and OUT_DIR to be provided (either env vars or by run.sh)
: "${INPUT_DIR:?INPUT_DIR is not set}"
: "${OUT_DIR:?OUT_DIR is not set}"

# Quote paths and avoid cd side effects by using full paths
mkdir -p "$OUT_DIR"

echo "DEBUG extractor MODE=$MODE SMOKE_TOTAL_FRAMES=${SMOKE_TOTAL_FRAMES:-unset}"

# Build an explicit list of matching videos, and error clearly if none
#VIDEOS=( "$INPUT_DIR"/*.MOV "$INPUT_DIR"/*.mov "$INPUT_DIR"/*.avi "$INPUT_DIR"/*.mp4 "$INPUT_DIR"/*.mkv )
#if [[ ${#VIDEOS[@]} -eq 0 ]]; then
#  echo "No videos found in: $INPUT_DIR (expected .mov .avi .mp4 .mkv)"
#  exit 1
#fi

VIDEOS=()

while IFS= read -r -d '' f; do
  if ffprobe -v error -select_streams v:0 \
      -show_entries stream=codec_type -of csv=p=0 "$f" >/dev/null 2>&1; then
    VIDEOS+=( "$f" )
  fi
done < <(find "$INPUT_DIR" -maxdepth 1 -type f \( \
    -iname '*.mov' -o -iname '*.mp4' -o -iname '*.m4v' -o -iname '*.mkv' -o -iname '*.avi' -o \
    -iname '*.webm' -o -iname '*.mpg' -o -iname '*.mpeg' -o -iname '*.ts' -o -iname '*.m2ts' -o \
    -iname '*.mts' -o -iname '*.mxf' -o -iname '*.wmv' -o -iname '*.flv' -o -iname '*.3gp' -o \
    -iname '*.ogv' -o -iname '*.mjpeg' \
  \) -print0)

if (( ${#VIDEOS[@]} == 0 )); then
  echo "No videos found in: $INPUT_DIR"
  exit 1
fi

MODE="${MODE:-normal}"  # normal | smoke

# Normal mode: whatever you want (example)
FPS_FILTER="${FPS_FILTER:-4}"  # for short clips, 4–8 fps is often sane

# Smoke mode caps
SMOKE_TOTAL_FRAMES="${SMOKE_TOTAL_FRAMES:-100}"   # total across ALL videos
SMOKE_MAX_PER_VIDEO="${SMOKE_MAX_PER_VIDEO:-30}"  # optional per-video cap
SMOKE_SECONDS="${SMOKE_SECONDS:-0}"               # 0 = no time cap
SMOKE_TARGET_FRAMES="${SMOKE_TARGET_FRAMES:-30}"  # used to compute fps dynamically
MIN_FPS="${MIN_FPS:-2}"
MAX_FPS="${MAX_FPS:-12}"

remaining="$SMOKE_TOTAL_FRAMES"
declare -a t_args=()

for video in "${VIDEOS[@]}"; do
  base="$(basename "${video%.*}")"

  if [[ "$MODE" == "smoke" ]]; then
    # Stop when we hit the global budget
    if (( remaining <= 0 )); then
      break
    fi

    # Decide how many frames we can still afford for this video
    frames_for_video="$SMOKE_MAX_PER_VIDEO"
    if (( frames_for_video > remaining )); then
      frames_for_video="$remaining"
    fi

    # Compute fps aiming for ~SMOKE_TARGET_FRAMES, clamped
    duration="$(
      ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$video" || echo 0
    )"

    fps="$(
      awk -v d="$duration" -v t="$SMOKE_TARGET_FRAMES" -v min="$MIN_FPS" -v max="$MAX_FPS" 'BEGIN{
        if (d <= 0.01) d = 1;
        f = t / d;
        if (f < min) f = min;
        if (f > max) f = max;
        printf "%.3f", f;
      }'
    )"

    # cap by seconds when videos are long
    t_args=()
    if [[ "$SMOKE_SECONDS" != "0" ]]; then
      t_args=( -t "$SMOKE_SECONDS" )
    fi

    ffmpeg -hide_banner -loglevel error -y \
      -i "$video" \
      -an -sn -dn \
      ${t_args[@]+"${t_args[@]}"} \
      -vf "fps=$fps,setsar=1,format=yuvj420p" \
      -frames:v "$frames_for_video" \
      -q:v 5 -pix_fmt yuvj420p -strict unofficial \
      "$OUT_DIR/${base}_frame_%09d.jpg"

    remaining=$(( remaining - frames_for_video ))

  else
    ffmpeg -hide_banner -loglevel error -y \
      -i "$video" \
      -an -sn -dn \
      -vf "fps=$FPS_FILTER,setsar=1,format=yuvj420p" \
      -q:v 5 -pix_fmt yuvj420p -strict unofficial \
      "$OUT_DIR/${base}_frame_%09d.jpg"
  fi
done


