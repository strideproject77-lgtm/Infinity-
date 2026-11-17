#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_FILE="$ROOT/Vendor/StikJIT/UPSTREAM.txt"
IDEVICE_DIR="$ROOT/Vendor/StikJIT/idevice"
ARCHIVE="$IDEVICE_DIR/libidevice_ffi.a"
TEMP_ARCHIVE="$ARCHIVE.download"

UPSTREAM_REPO="$(sed -n '1p' "$UPSTREAM_FILE" | tr -d '\r')"
UPSTREAM_COMMIT="$(sed -n '2p' "$UPSTREAM_FILE" | tr -d '\r')"
EXPECTED_GIT_BLOB="3fb7e2dbfdb9db3d47bd6364a435bbc10d5581f9"

if [[ "$UPSTREAM_REPO" != "https://github.com/StikDebug/StikJIT" ]]; then
  echo "Unexpected StikJIT upstream URL: $UPSTREAM_REPO" >&2
  exit 1
fi
if [[ "$UPSTREAM_COMMIT" != "32287268fa5824f9edce4cb359f5833ce0cf7b00" ]]; then
  echo "StikJIT pin changed; review the new upstream archive and update its verified Git blob hash." >&2
  exit 1
fi

if [[ -f "$ARCHIVE" ]] && [[ "$(git -C "$ROOT" hash-object "$ARCHIVE")" == "$EXPECTED_GIT_BLOB" ]]; then
  echo "Pinned idevice_ffi archive already present."
else
  rm -f "$TEMP_ARCHIVE"
  curl --fail --location --retry 3 --retry-delay 2 --connect-timeout 30 \
    "$UPSTREAM_REPO/raw/$UPSTREAM_COMMIT/idevice/libidevice_ffi.a" \
    --output "$TEMP_ARCHIVE"
  ACTUAL_GIT_BLOB="$(git -C "$ROOT" hash-object "$TEMP_ARCHIVE")"
  if [[ "$ACTUAL_GIT_BLOB" != "$EXPECTED_GIT_BLOB" ]]; then
    echo "Pinned idevice_ffi archive hash mismatch: $ACTUAL_GIT_BLOB" >&2
    rm -f "$TEMP_ARCHIVE"
    exit 1
  fi
  mv "$TEMP_ARCHIVE" "$ARCHIVE"
fi

lipo -verify_arch arm64 "$ARCHIVE"
SYMBOLS_FILE="$(mktemp)"
trap 'rm -f "$SYMBOLS_FILE"' EXIT
if ! nm -gU "$ARCHIVE" > "$SYMBOLS_FILE"; then
  echo "Unable to inspect the pinned idevice_ffi archive symbols." >&2
  exit 1
fi
if ! grep -q 'idevice_error_free' "$SYMBOLS_FILE"; then
  echo "Pinned idevice_ffi archive does not export idevice_error_free." >&2
  exit 1
fi

echo "Verified StikJIT idevice_ffi archive for iOS arm64."
