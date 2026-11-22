#!/usr/bin/env bash
# Canonical build pipeline shared by GitHub Actions and Codemagic.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

: "${scheme:=LiveContainer}"
: "${archive_path:=archive}"
ARCHIVE_PATH="$archive_path"
case "$ARCHIVE_PATH" in
  *.xcarchive) ;;
  *) ARCHIVE_PATH="${ARCHIVE_PATH}.xcarchive" ;;
esac
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
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  2>&1 | tee "$ARCHIVE_LOG"

# Reuse the repository's existing packaging implementation unchanged.
sh .github/build_github.sh

test -s "$scheme.ipa"
test -s "$scheme+SideStore.ipa"
echo "Canonical INFINITY build and packaging completed."
