#!/usr/bin/env bash
# Import the pinned Husk native translation-layer sources without importing
# Husk's app, QEMU guest, UI, packaging, or unrelated build system.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/Vendor/Husk"
REVISION="29abb512d81bf8cc08babcbe7f7007cb557208ef"
UPSTREAM="https://github.com/Leviidev/Husk.git"
REFRESH=0

if [[ "${1:-}" == "--refresh" ]]; then
  REFRESH=1
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--refresh]" >&2
  exit 2
fi

if [[ -e "$DEST/translation-layer-next" && "$REFRESH" -ne 1 ]]; then
  echo "Husk sources already exist. Review the diff, then rerun with --refresh." >&2
  exit 3
fi

command -v git >/dev/null || { echo "git is required" >&2; exit 4; }
command -v tar >/dev/null || { echo "tar is required" >&2; exit 4; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[fetch] Husk $REVISION"
git init -q "$TMP/repo"
git -C "$TMP/repo" remote add origin "$UPSTREAM"
git -C "$TMP/repo" fetch --quiet --depth 1 origin "$REVISION"

ACTUAL="$(git -C "$TMP/repo" rev-parse FETCH_HEAD)"
[[ "$ACTUAL" == "$REVISION" ]] || { echo "Fetched revision mismatch" >&2; exit 5; }

mkdir -p "$TMP/archive"
git -C "$TMP/repo" archive --format=tar "$REVISION" \
  src/translation-layer-next LICENSE docs/01-licensing.md | tar -xf - -C "$TMP/archive"

SOURCE="$TMP/archive/src/translation-layer-next"
[[ -d "$SOURCE" ]] || { echo "Pinned source tree missing" >&2; exit 6; }
[[ -f "$TMP/archive/LICENSE" && -f "$TMP/archive/docs/01-licensing.md" ]] || {
  echo "Required upstream license material missing" >&2; exit 7;
}

# Stage everything first; only replace the destination after validation.
STAGE="$TMP/stage"
mkdir -p "$STAGE"
cp -R "$SOURCE" "$STAGE/translation-layer-next"
cp "$TMP/archive/LICENSE" "$STAGE/HUSK-LICENSE"
cp "$TMP/archive/docs/01-licensing.md" "$STAGE/HUSK-LICENSING-GUIDE.md"
cat > "$STAGE/UPSTREAM_REVISION.txt" <<EOF
Repository: https://github.com/Leviidev/Husk
Revision: $REVISION
Imported path: src/translation-layer-next
Import date: $(date -u +%Y-%m-%d)
Method: git archive from the exact pinned commit
EOF

FILE_COUNT="$(find "$STAGE/translation-layer-next" -type f | wc -l | tr -d ' ')"
[[ "$FILE_COUNT" -gt 0 ]] || { echo "Imported source tree is empty" >&2; exit 8; }

mkdir -p "$DEST"
if [[ -e "$DEST/translation-layer-next" ]]; then
  rm -rf "$DEST/translation-layer-next"
fi
rm -f "$DEST/HUSK-LICENSE" "$DEST/HUSK-LICENSING-GUIDE.md" "$DEST/UPSTREAM_REVISION.txt"
cp -R "$STAGE/." "$DEST/"

echo "[done] Imported $FILE_COUNT files from Husk $REVISION"
echo "Review per-file provenance and dependencies before adding any file to an Xcode target."
