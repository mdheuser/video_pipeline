#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <input_dir> <output_dir> [--smoke]"
  exit 1
}

IMG="${IMG:-video-pipeline}"
IN_DIR="${1:-}"
OUT_DIR="${2:-}"
SMOKE_FLAG="${3:-}"

[ -n "$IN_DIR" ] || usage
[ -n "$OUT_DIR" ] || usage

if [ ! -d "$IN_DIR" ]; then
  echo "❌ Input dir not found: $IN_DIR"
  exit 1
fi

mkdir -p "$OUT_DIR"

CID="$(docker create "$IMG" /data/input /data/output ${SMOKE_FLAG})"
TMP_DIR=""

cleanup() {
  if [ -n "${TMP_DIR:-}" ] && [ -d "${TMP_DIR:-}" ]; then
    rm -rf "$TMP_DIR" || true
  fi
  docker rm -f "$CID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Build tar flags as a string. Key: force --format=ustar (ustar can't carry xattrs/pax metadata).
TAR_FLAGS="--format=ustar"
HELP_TEXT="$(tar --help 2>&1 || true)"

echo "$HELP_TEXT" | grep -q -- "--no-xattrs" && TAR_FLAGS="$TAR_FLAGS --no-xattrs"
echo "$HELP_TEXT" | grep -q -- "--no-mac-metadata" && TAR_FLAGS="$TAR_FLAGS --no-mac-metadata"

echo "Copying input into container (attempt 1: tar without mac metadata/xattrs)..."
set +e
COPYFILE_DISABLE=1 tar $TAR_FLAGS -C "$IN_DIR" -cf - . | docker cp - "$CID:/data/input"
STATUS=$?
set -e

if [ $STATUS -ne 0 ]; then
  echo "⚠️  Copy failed (likely due to macOS xattrs). Creating a temp copy without xattrs and retrying..."

  TMP_DIR="$(mktemp -d)"

  # Prefer ditto (best on macOS for stripping metadata), fallback to cp -X (no xattrs)
  if command -v ditto >/dev/null 2>&1; then
    # --noextattr: no extended attributes, --norsrc: no resource forks
    ditto --noextattr --norsrc "$IN_DIR" "$TMP_DIR"
  else
    # -R: recursive, -X: don't copy xattrs
    cp -R -X "$IN_DIR"/. "$TMP_DIR"/
  fi

  echo "Copying input into container (attempt 2: from sanitized temp copy)..."
  COPYFILE_DISABLE=1 tar --format=ustar -C "$TMP_DIR" -cf - . | docker cp - "$CID:/data/input"
fi

echo "Running container..."
docker start -a "$CID"

echo "Copying output back to host..."
docker cp "$CID:/data/output/." - | COPYFILE_DISABLE=1 tar -C "$OUT_DIR" -xf -
