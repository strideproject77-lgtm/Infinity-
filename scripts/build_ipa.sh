#!/usr/bin/env bash
# Canonical build pipeline shared by GitHub Actions and Codemagic.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

: "${scheme:=LiveContainer}"
export scheme
: "${archive_path:=archive}"
ARCHIVE_BASE="${archive_path%.xcarchive}"
ARCHIVE_PATH="${ARCHIVE_BASE}.xcarchive"
archive_path="$ARCHIVE_BASE"
export archive_path
ARCHIVE_LOG="${INFINITY_ARCHIVE_LOG:-/tmp/xcodebuild-archive.log}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "INFINITY IPA builds require a macOS/Xcode runner." >&2
  exit 2
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is unavailable; select the pinned Xcode 26.2 toolchain." >&2
  exit 2
fi
XCODE_VERSION="$(xcodebuild -version | awk '/^Xcode / {print $2; exit}')"
if [[ "$XCODE_VERSION" != "26.2" ]]; then
  echo "Toolchain mismatch: expected Xcode 26.2, found ${XCODE_VERSION:-unknown}." >&2
  exit 2
fi

echo "INFINITY canonical build"
echo "Scheme: $scheme"
echo "Archive: $ARCHIVE_PATH"
echo "Xcode: $XCODE_VERSION"

bash scripts/prepare_stikjit_idevice.sh
bash scripts/prepare_infinity_app_icon.sh

WORKSPACE="$(find . -maxdepth 1 -name '*.xcworkspace' -print -quit)"
PROJECT="$(find . -maxdepth 1 -name '*.xcodeproj' -print -quit)"
if [[ -n "$WORKSPACE" ]]; then
  XCODE_CONTAINER=(-workspace "$WORKSPACE")
elif [[ -n "$PROJECT" ]]; then
  XCODE_CONTAINER=(-project "$PROJECT")
else
  echo "No Xcode workspace or project found at repository root." >&2
  exit 2
fi

xcodebuild -resolvePackageDependencies "${XCODE_CONTAINER[@]}" -scheme "$scheme"

mkdir -p "$(dirname "$ARCHIVE_LOG")"
set -o pipefail
xcodebuild archive \
  -archivePath "$ARCHIVE_PATH" \
  -scheme "$scheme" \
  "${XCODE_CONTAINER[@]}" \
  -sdk iphoneos \
  -arch arm64 \
  -configuration Release \
  -jobs 1 \
  SWIFT_COMPILATION_MODE=singlefile \
  SWIFT_OPTIMIZATION_LEVEL=-Onone \
  2>&1 | tee "$ARCHIVE_LOG"

# Match the upstream LiveContainer Nightly signing behavior. The app-group
# entitlements must be embedded in the host app and guest process extension.
APP_BUNDLE="$ARCHIVE_PATH/Products/Applications/LiveContainer.app"
LIVE_PROCESS_EXTENSION="$APP_BUNDLE/PlugIns/LiveProcess.appex"
if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Archived LiveContainer.app is missing: $APP_BUNDLE" >&2
  exit 2
fi
if [[ ! -d "$LIVE_PROCESS_EXTENSION" ]]; then
  echo "Archived LiveProcess.appex is missing: $LIVE_PROCESS_EXTENSION" >&2
  exit 2
fi
verify_app_group_entitlement() {
  local bundle="$1"
  local label="$2"
  local entitlements
  entitlements="$(codesign -d --entitlements :- "$bundle" 2>&1)" || {
    echo "Unable to read code-signing entitlements for $label." >&2
    return 1
  }
  if ! grep -Fq "group.com.SideStore.SideStore" <<<"$entitlements"; then
    echo "$label is missing the SideStore App Group entitlement." >&2
    return 1
  fi
  if ! grep -Fq "group.com.rileytestut.AltStore" <<<"$entitlements"; then
    echo "$label is missing the AltStore compatibility App Group entitlement." >&2
    return 1
  fi
  echo "Verified SideStore and AltStore App Group entitlements: $label"
}
verify_app_group_entitlement "$APP_BUNDLE" "LiveContainer.app"
verify_app_group_entitlement "$LIVE_PROCESS_EXTENSION" "LiveProcess.appex"

# Reuse the repository's existing packaging implementation unchanged.
sh .github/build_github.sh

test -s "$scheme.ipa"
test -s "$scheme+SideStore.ipa"
echo "Canonical INFINITY build and packaging completed."
