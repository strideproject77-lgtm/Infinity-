#!/usr/bin/env bash
# Capture the canonical build byte-for-byte while streaming it to Codemagic's console.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOG_DIR="${INFINITY_CODEMAGIC_LOG_DIR:-/tmp/infinity-codemagic-logs}"
BUILD_LOG="$LOG_DIR/build.log"
ARCHIVE_LOG="$LOG_DIR/xcodebuild-archive.log"
# build_ipa.sh reads this exact variable for the raw xcodebuild archive transcript.
export INFINITY_ARCHIVE_LOG="$ARCHIVE_LOG"
SUBMODULE_LOG="$LOG_DIR/submodules.log"
mkdir -p "$LOG_DIR"
: > "$BUILD_LOG"
: > "$ARCHIVE_LOG"

# Record runner/build identity before starting the compiler.
{
  echo "INFINITY Codemagic build wrapper"
  echo "Logs: $LOG_DIR"
  echo "Commit: ${CM_COMMIT:-unknown}"
  echo "Build ID: ${CM_BUILD_ID:-unknown}"
  echo "Build number: ${CM_BUILD_NUMBER:-unknown}"
  echo "Started UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} | tee -a "$BUILD_LOG"

# Use a byte-streaming subprocess rather than a shell pipeline. This avoids
# PIPESTATUS/tee edge cases and guarantees the file is flushed before publish.
set +e
python3 - "$BUILD_LOG" <<'PY'
import subprocess
import sys

log_path = sys.argv[1]
status = 1
with open(log_path, "ab", buffering=0) as log:
    process = subprocess.Popen(
        ["bash", "scripts/build_ipa.sh"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=0,
    )
    assert process.stdout is not None
    while True:
        chunk = process.stdout.read(64 * 1024)
        if not chunk:
            break
        log.write(chunk)
        sys.stdout.buffer.write(chunk)
        sys.stdout.buffer.flush()
    status = process.wait()
    trailer = f"\n[INFINITY] build process exit code: {status}\n".encode()
    log.write(trailer)
    sys.stdout.buffer.write(trailer)
    sys.stdout.buffer.flush()
sys.exit(status)
PY
BUILD_STATUS=$?
set -e

# Xcode version is recorded in metadata; the canonical build validates the pin.
if command -v xcodebuild >/dev/null 2>&1; then
  export INFINITY_XCODE_VERSION="$(xcodebuild -version 2>/dev/null | awk '/^Xcode / {print $2; exit}')"
else
  export INFINITY_XCODE_VERSION="unavailable"
fi

export INFINITY_CODEMAGIC_BUILD_EXIT_CODE="$BUILD_STATUS"
export INFINITY_CODEMAGIC_BUILD_LOG="$BUILD_LOG"
export INFINITY_CODEMAGIC_ARCHIVE_LOG="$ARCHIVE_LOG"
export INFINITY_CODEMAGIC_SUBMODULE_LOG="$SUBMODULE_LOG"

if [[ -n "${INFINITY_LOGS_GITHUB_TOKEN:-}" ]]; then
  set +e
  bash scripts/publish_codemagic_logs.sh 2>&1 | tee -a "$BUILD_LOG"
  PUBLISH_STATUS=${PIPESTATUS[0]}
  set -e
  if [[ "$PUBLISH_STATUS" -ne 0 ]]; then
    echo "WARNING: GitHub log publication failed (status $PUBLISH_STATUS); original build result is preserved." | tee -a "$BUILD_LOG"
  fi
else
  echo "WARNING: INFINITY_LOGS_GITHUB_TOKEN is not configured; logs remain available as Codemagic artifacts." | tee -a "$BUILD_LOG"
fi

exit "$BUILD_STATUS"
