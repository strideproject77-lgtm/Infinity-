#!/usr/bin/env bash
# Compile-only audit of the pinned Husk translation-layer sources against the
# iPhoneOS SDK. This intentionally does not link, archive, sign, or package an app.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$ROOT/Vendor/Husk"
OLD="$VENDOR/translation-layer"
NEXT="$VENDOR/translation-layer-next"

for dir in "$OLD" "$NEXT"; do
  if [[ ! -d "$dir" ]]; then
    echo "error: expected vendored source tree missing: $dir" >&2
    exit 2
  fi
done

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CLANG="$(xcrun --sdk iphoneos --find clang)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

find "$OLD" "$NEXT" -type f \\( -name '*.c' -o -name '*.m' \\) -print | LC_ALL=C sort > "$TMP/sources.txt"
COUNT="$(wc -l < "$TMP/sources.txt" | tr -d ' ')"
if [[ "$COUNT" -lt 1 ]]; then
  echo "error: no native translation sources found" >&2
  exit 2
fi

echo "Husk source compile-only audit: $COUNT translation sources"
echo "SDK: $SDK"
echo "Target: arm64-apple-ios15.0"
FAILURES=0
while IFS= read -r source; do
  relative="${source#"$VENDOR"/}"
  echo "::group::Compile $relative"
  common=(
    -target arm64-apple-ios15.0
    -isysroot "$SDK"
    -fsyntax-only
    -fblocks
    -D_DARWIN_C_SOURCE
    -I"$OLD"
    -I"$NEXT"
    -I"$VENDOR"
  )
  if [[ "$source" == *.m ]]; then
    if "$CLANG" "${common[@]}" -fobjc-arc "$source"; then
      echo "PASS $relative"
    else
      echo "FAIL $relative"
      FAILURES=$((FAILURES + 1))
    fi
  else
    if "$CLANG" "${common[@]}" "$source"; then
      echo "PASS $relative"
    else
      echo "FAIL $relative"
      FAILURES=$((FAILURES + 1))
    fi
  fi
  echo "::endgroup::"
done < "$TMP/sources.txt"

echo "Compile-only summary: $((COUNT - FAILURES))/$COUNT passed; $FAILURES failed."
if [[ "$FAILURES" -ne 0 ]]; then
  exit 1
fi
