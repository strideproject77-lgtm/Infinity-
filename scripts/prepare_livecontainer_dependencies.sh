#!/usr/bin/env bash
# Restore the exact OpenSSL XCFramework required by the current LiveContainer project.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/Dependencies/OpenSSL.xcframework"
URL="https://github.com/krzyzanowskim/OpenSSL/releases/download/3.6.5000/OpenSSL.xcframework.zip"
SHA256="f50188506490c643715489217d32e458d06cee5579399ff616f0ce2038169fea"

if [[ -f "$DEST/Info.plist" ]]; then
  echo "Verified OpenSSL XCFramework is already present."
  exit 0
fi

if [[ -e "$DEST" ]]; then
  rm -rf "$DEST"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/infinity-openssl.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$ROOT/Dependencies"
curl --fail --location --retry 3 --retry-all-errors "$URL" --output "$TMP_DIR/OpenSSL.xcframework.zip"
printf '%s  %s\n' "$SHA256" "$TMP_DIR/OpenSSL.xcframework.zip" | shasum -a 256 -c -
mkdir -p "$TMP_DIR/unpacked"
unzip -q "$TMP_DIR/OpenSSL.xcframework.zip" -d "$TMP_DIR/unpacked"
test -f "$TMP_DIR/unpacked/OpenSSL.xcframework/Info.plist"
mv "$TMP_DIR/unpacked/OpenSSL.xcframework" "$DEST"

echo "OpenSSL 3.6.5000 XCFramework restored and checksum-verified."
