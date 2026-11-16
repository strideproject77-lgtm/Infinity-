#!/usr/bin/env bash
# Import Husk's native translation engine and its selected iOS host-side runtime
# sources as an isolated, pinned vendor snapshot. Nothing is added to an Xcode
# target by this script.
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

# Stage the exact native engine, selected host-side runtime code, runtime build
# recipes and technical/licensing documents. Deliberately exclude Husk's app
# entry point, UI/catalog, QEMU guest orchestration, QEMU binaries, JIT helper,
# signing/refresh flows, and unrelated app features.
ARCHIVE="$TMP/archive"
mkdir -p "$ARCHIVE"
git -C "$TMP/repo" archive --format=tar "$REVISION" \
  src/translation-layer-next \
  src/app/Husk/TLUnityView.swift \
  src/app/Husk/TLAppSettings.swift \
  src/app/Husk/HuskGamepad.swift \
  src/app/Husk/HuskKeyboard.swift \
  src/app/Husk/HuskLog.swift \
  src/app/Husk/HuskFilePicker.swift \
  scripts/build_java_runtime.sh \
  scripts/build_android_system.sh \
  scripts/build_angle_ios.sh \
  scripts/build_art_support.sh \
  docs/00-architecture.md \
  docs/01-licensing.md \
  docs/04-translation-layer.md \
  docs/05-translation-layer-milestone2-handoff.md \
  LICENSE | tar -xf - -C "$ARCHIVE"

[[ -d "$ARCHIVE/src/translation-layer-next" ]] || { echo "Pinned native runtime source tree missing" >&2; exit 6; }
[[ -f "$ARCHIVE/LICENSE" && -f "$ARCHIVE/docs/01-licensing.md" ]] || {
  echo "Required upstream license material missing" >&2; exit 7;
}

STAGE="$TMP/stage"
mkdir -p "$STAGE/translation-layer-next" "$STAGE/host-runtime" "$STAGE/build-support" "$STAGE/upstream-docs"
cp -R "$ARCHIVE/src/translation-layer-next/." "$STAGE/translation-layer-next/"
for file in TLUnityView.swift TLAppSettings.swift HuskGamepad.swift HuskKeyboard.swift HuskLog.swift HuskFilePicker.swift; do
  cp "$ARCHIVE/src/app/Husk/$file" "$STAGE/host-runtime/$file"
done
for file in build_java_runtime.sh build_android_system.sh build_angle_ios.sh build_art_support.sh; do
  cp "$ARCHIVE/scripts/$file" "$STAGE/build-support/$file"
done
for file in 00-architecture.md 01-licensing.md 04-translation-layer.md 05-translation-layer-milestone2-handoff.md; do
  cp "$ARCHIVE/docs/$file" "$STAGE/upstream-docs/$file"
done
cp "$ARCHIVE/LICENSE" "$STAGE/HUSK-LICENSE"

cat > "$STAGE/UPSTREAM_REVISION.txt" <<EOF
Repository: https://github.com/Leviidev/Husk
Revision: $REVISION
Native source: src/translation-layer-next
Selected host runtime: src/app/Husk/{TLUnityView,TLAppSettings,HuskGamepad,HuskKeyboard,HuskLog,HuskFilePicker}.swift
Build recipes: scripts/{build_java_runtime,build_android_system,build_angle_ios,build_art_support}.sh
Technical docs: docs/{00-architecture,01-licensing,04-translation-layer,05-translation-layer-milestone2-handoff}.md
Import date: $(date -u +%Y-%m-%d)
Method: git archive from the exact pinned commit
EOF

NATIVE_COUNT="$(find "$STAGE/translation-layer-next" -type f | wc -l | tr -d ' ')"
HOST_COUNT="$(find "$STAGE/host-runtime" -type f | wc -l | tr -d ' ')"
[[ "$NATIVE_COUNT" -gt 0 && "$HOST_COUNT" -gt 0 ]] || { echo "Imported source groups are incomplete" >&2; exit 8; }

# Replace only the paths owned by this importer. Preserve THIRD_PARTY_NOTICES.md
# and any other INFINITY-owned files in Vendor/Husk.
mkdir -p "$DEST"
for path in translation-layer-next host-runtime build-support upstream-docs; do
  rm -rf "$DEST/$path"
  cp -R "$STAGE/$path" "$DEST/$path"
done
cp "$STAGE/HUSK-LICENSE" "$DEST/HUSK-LICENSE"
cp "$STAGE/UPSTREAM_REVISION.txt" "$DEST/UPSTREAM_REVISION.txt"

echo "[done] Imported $NATIVE_COUNT native files and $HOST_COUNT host-runtime Swift files from Husk $REVISION"
echo "No Xcode target was changed. Complete dependency, licensing, and host-API review before compiling."
