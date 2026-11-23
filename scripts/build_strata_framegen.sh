#!/usr/bin/env bash
# Build the guest-only Strata Metal frame-generation engine for arm64 iOS.
# MetalFGWarper embeds its MSL source, so no external metallib is required.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-}"
if [[ -z "$OUTPUT" ]]; then
  echo "Usage: $0 <path/to/StrataFrameGen.dylib>" >&2
  exit 2
fi
if [[ "$(uname -s)" != "Darwin" ]] || ! command -v xcrun >/dev/null 2>&1; then
  echo "Strata frame generation requires an Xcode macOS runner." >&2
  exit 2
fi

SDKROOT="$(xcrun --sdk iphoneos --show-sdk-path)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/infinity-framegen.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
BINARY="$TMP_DIR/StrataFrameGen.dylib"

SOURCES=(
  "$ROOT/FrameGeneration/StrataFrameGen.mm"
  "$ROOT/Vendor/MetalFG/Source/TouchTracker.mm"
  "$ROOT/Vendor/MetalFG/Source/CoreMotionTracker.mm"
  "$ROOT/Vendor/MetalFG/Source/MetalFGWarper.mm"
  "$ROOT/Vendor/MetalFG/Source/MetalFGSynchronizer.mm"
  "$ROOT/Vendor/MetalFG/Source/MetalFGOverlay.mm"
)
for source in "${SOURCES[@]}"; do
  if [[ ! -f "$source" ]]; then
    echo "Required MetalFG source is missing: $source" >&2
    exit 2
  fi
done

xcrun --sdk iphoneos clang++ \
  -dynamiclib \
  -arch arm64 \
  -isysroot "$SDKROOT" \
  -miphoneos-version-min=16.0 \
  -fobjc-arc \
  -std=c++17 \
  -O2 \
  -I "$ROOT/Vendor/MetalFG/Headers" \
  "${SOURCES[@]}" \
  -framework Foundation \
  -framework UIKit \
  -framework Metal \
  -framework QuartzCore \
  -framework CoreMotion \
  -framework CoreGraphics \
  -Wl,-install_name,@rpath/StrataFrameGen.dylib \
  -o "$BINARY"

if ! nm -g "$BINARY" | grep -q "StrataFrameGenStart"; then
  echo "Built frame-generation dylib does not export StrataFrameGenStart." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
install -m 755 "$BINARY" "$OUTPUT"
codesign --force --sign - --timestamp=none "$OUTPUT"
echo "Built and signed guest-only frame-generation library: $OUTPUT"
