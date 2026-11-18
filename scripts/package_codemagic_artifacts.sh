#!/usr/bin/env bash
# Combine the two exported IPAs, Xcode archive, and build diagnostics into one download.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PACKAGE_NAME="INFINITY-Complete-Artifacts"
OUTPUT="$ROOT/${PACKAGE_NAME}.zip"
LOG_DIR="${INFINITY_CODEMAGIC_LOG_DIR:-/tmp/infinity-codemagic-logs}"
STAGE="$(mktemp -d)"
PACKAGE_ROOT="$STAGE/$PACKAGE_NAME"
trap 'rm -rf "$STAGE"' EXIT

# Fail rather than publish an incomplete package.
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

mkdir -p "$PACKAGE_ROOT/build-logs"
cp -p "LiveContainer.ipa" "$PACKAGE_ROOT/"
cp -p "LiveContainer+SideStore.ipa" "$PACKAGE_ROOT/"
ditto "archive.xcarchive" "$PACKAGE_ROOT/archive.xcarchive"

# Include the same diagnostic material that was previously delivered separately.
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

rm -f "$OUTPUT"
ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_ROOT" "$OUTPUT"
test -s "$OUTPUT"
unzip -t "$OUTPUT" >/dev/null
echo "Created and validated: $OUTPUT"
