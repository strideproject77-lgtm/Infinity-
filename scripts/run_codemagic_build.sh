#!/usr/bin/env bash
# Run the canonical build and publish a fresh, sanitized copy of its logs to GitHub.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOG_DIR="${INFINITY_CODEMAGIC_LOG_DIR:-/tmp/infinity-codemagic-logs}"
BUILD_LOG="$LOG_DIR/build.log"
ARCHIVE_LOG="$LOG_DIR/xcodebuild-archive.log"
mkdir -p "$LOG_DIR"
: > "$BUILD_LOG"
: > "$ARCHIVE_LOG"

export INFINITY_ARCHIVE_LOG="$ARCHIVE_LOG"
export INFINITY_XCODE_VERSION="$(xcodebuild -version | sed -n '1s/^Xcode //p')"

echo "INFINITY Codemagic build wrapper"
echo "Logs: $LOG_DIR"
echo "Commit: ${CM_COMMIT:-unknown}"
echo "Build: ${CM_BUILD_NUMBER:-unknown}"

set +e
bash scripts/build_ipa.sh 2>&1 | tee "$BUILD_LOG"
BUILD_STATUS=${PIPESTATUS[0]}
set -e

export INFINITY_CODEMAGIC_BUILD_EXIT_CODE="$BUILD_STATUS"
export INFINITY_CODEMAGIC_BUILD_LOG="$BUILD_LOG"
export INFINITY_CODEMAGIC_ARCHIVE_LOG="$ARCHIVE_LOG"

if [[ -n "${INFINITY_LOGS_GITHUB_TOKEN:-}" ]]; then
  if ! bash scripts/publish_codemagic_logs.sh; then
    echo "WARNING: GitHub log publication failed. The original build result is preserved."
  fi
else
  echo "WARNING: INFINITY_LOGS_GITHUB_TOKEN is not configured in Codemagic; logs remain available as Codemagic artifacts only."
fi

exit "$BUILD_STATUS"
