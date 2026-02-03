#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

FRAMES_DIR="${1:-}"

if [[ -z "$FRAMES_DIR" ]]; then
  echo "Usage: $0 <frames_dir>"
  exit 1
fi

if [[ ! -d "$FRAMES_DIR" ]]; then
  echo "Frames directory not found: $FRAMES_DIR"
  exit 1
fi

echo "Randomizing file order and renaming sequentially..."
cd "$FRAMES_DIR"

# Ensure there are jpgs
if ! ls *.jpg >/dev/null 2>&1; then
  echo "No .jpg files found in: $FRAMES_DIR"
  exit 1
fi

TEMP_DIR="$(mktemp -d)"

counter=1

# Python prints shuffled filenames, one per line.
python3 - <<'PY' | while IFS= read -r f; do
import glob, random
files = glob.glob("*.jpg")
random.shuffle(files)
for x in files:
    print(x)
PY
  # Skip empty lines defensively
  [[ -z "${f:-}" ]] && continue

  mv -- "$f" "$TEMP_DIR/$(printf "%09d.jpg" "$counter")"
  counter=$((counter + 1))
done

# Move sequential files back
mv -- "$TEMP_DIR"/*.jpg .
rmdir -- "$TEMP_DIR"

echo "✅ Renaming complete. Files are now named sequentially from 000000001.jpg"
