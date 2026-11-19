#!/usr/bin/env bash
# Produce separate LiveContainer and LiveContainer+SideStore ZIPs, plus the full diagnostics bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOG_DIR="${INFINITY_CODEMAGIC_LOG_DIR:-/tmp/infinity-codemagic-logs}"
LIVE_ONLY_ZIP="$ROOT/INFINITY-LiveContainer-Only.zip"
SIDESTORE_ZIP="$ROOT/INFINITY-LiveContainer-SideStore.zip"
COMPLETE_ZIP="$ROOT/INFINITY-Complete-Artifacts.zip"
STAGE="$(mktemp -d)"
PACKAGE_NAME="INFINITY-Complete-Artifacts"
PACKAGE_ROOT="$STAGE/$PACKAGE_NAME"
trap 'rm -rf "$STAGE"' EXIT

# Fail rather than publish incomplete outputs.
for required in "LiveContainer.ipa" "LiveContainer+SideStore.ipa"; do
  if [[ ! -s "$required" ]]; then
    echo "Required IPA is missing or empty: $required" >&2
    exit 1
  fi
done
if [[ ! -d "archive.xcarchive" ]]; then
  echo "Required Xcode archive is missing: archive.xcarchive" >&2
  exit 1
fi

# ZIP 1: only the standard LiveContainer IPA, stored at the ZIP root.
rm -f "$LIVE_ONLY_ZIP"
zip -q -j "$LIVE_ONLY_ZIP" "LiveContainer.ipa"
unzip -t "$LIVE_ONLY_ZIP" >/dev/null
echo "Created and validated: $LIVE_ONLY_ZIP"

# ZIP 2: only the LiveContainer build that includes SideStore support.
rm -f "$SIDESTORE_ZIP"
zip -q -j "$SIDESTORE_ZIP" "LiveContainer+SideStore.ipa"
unzip -t "$SIDESTORE_ZIP" >/dev/null
echo "Created and validated: $SIDESTORE_ZIP"

# ZIP 3: preserve the existing complete archive + logs bundle.
mkdir -p "$PACKAGE_ROOT/build-logs"
cp -p "LiveContainer.ipa" "$PACKAGE_ROOT/"
cp -p "LiveContainer+SideStore.ipa" "$PACKAGE_ROOT/"
ditto "archive.xcarchive" "$PACKAGE_ROOT/archive.xcarchive"

for name in build.log xcodebuild-archive.log submodules.log metadata.json; do
  if [[ -s "$LOG_DIR/$name" ]]; then
    cp -p "$LOG_DIR/$name" "$PACKAGE_ROOT/build-logs/$name"
  fi
done

{
  echo "INFINITY complete build artifacts"
  echo "Build ID: ${CM_BUILD_ID:-unknown}"
  echo "Build number: ${CM_BUILD_NUMBER:-unknown}"
  echo "Source commit: ${CM_COMMIT:-unknown}"
  echo "Created UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "Contents:"
  echo "- LiveContainer.ipa"
  echo "- LiveContainer+SideStore.ipa"
  echo "- archive.xcarchive/"
  echo "- build-logs/ (available Codemagic diagnostics)"
} > "$PACKAGE_ROOT/BUILD-INFO.txt"

rm -f "$COMPLETE_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_ROOT" "$COMPLETE_ZIP"
test -s "$COMPLETE_ZIP"
unzip -t "$COMPLETE_ZIP" >/dev/null
echo "Created and validated: $COMPLETE_ZIP"

# Final artifact sanity check: all three distinct ZIP files must be present.
for output in "$LIVE_ONLY_ZIP" "$SIDESTORE_ZIP" "$COMPLETE_ZIP"; do
  test -s "$output"
done
echo "All three INFINITY ZIP artifacts are ready."
