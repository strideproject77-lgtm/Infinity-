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

if [[ "$REFRESH" -ne 1 ]] && {
  [[ -e "$DEST/translation-layer" ]] ||
  [[ -e "$DEST/translation-layer-next" ]] ||
  [[ -e "$DEST/host-runtime" ]] ||
  [[ -e "$DEST/host-reference" ]] ||
  [[ -e "$DEST/build-support" ]] ||
  [[ -e "$DEST/upstream-docs" ]] ||
  [[ -e "$DEST/resources" ]] ||
  [[ -e "$DEST/src/java-framework" ]] ||
  [[ -e "$DEST/src/art-support" ]] ||
  [[ -e "$DEST/tools" ]] ||
  [[ -e "$DEST/scripts" ]] ||
  [[ -e "$DEST/HUSK-LICENSE" ]] ||
  [[ -e "$DEST/UPSTREAM_REVISION.txt" ]]
}; then
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
  src/translation-layer \
  src/translation-layer-next \
  src/app/Husk/TranslationLayer.swift \
  src/app/Husk/TLUnityView.swift \
  src/app/Husk/TLAppSettings.swift \
  src/app/Husk/AppWindows.swift \
  src/app/Husk/HuskGamepad.swift \
  src/app/Husk/HuskKeyboard.swift \
  src/app/Husk/HuskAudio.swift \
  src/app/Husk/HuskLog.swift \
  src/app/Husk/HuskFilePicker.swift \
  src/app/Husk/HuskApp.swift \
  src/app/Husk/HuskBridge.h \
  src/app/project.yml \
  src/app/Husk/Resources/cacert.pem \
  src/java-framework \
  src/art-support \
  tools/strip_framework_res.py \
  tools/compat \
  scripts/copy_aosp_bundle.sh \
  scripts/build_java_runtime.sh \
  scripts/build_android_system.sh \
  scripts/build_angle_ios.sh \
  scripts/build_art_support.sh \
  docs/00-architecture.md \
  docs/01-licensing.md \
  docs/04-translation-layer.md \
  docs/05-translation-layer-milestone2-handoff.md \
  LICENSE | tar -xf - -C "$ARCHIVE"

[[ -d "$ARCHIVE/src/translation-layer-next" && -d "$ARCHIVE/src/translation-layer" ]] || { echo "Pinned translation-layer source trees missing" >&2; exit 6; }
[[ -f "$ARCHIVE/LICENSE" && -f "$ARCHIVE/docs/01-licensing.md" ]] || {
  echo "Required upstream license material missing" >&2; exit 7;
}

STAGE="$TMP/stage"
mkdir -p "$STAGE/translation-layer" "$STAGE/translation-layer-next" "$STAGE/host-runtime" "$STAGE/host-reference" "$STAGE/build-support" "$STAGE/upstream-docs" "$STAGE/resources" "$STAGE/src/java-framework" "$STAGE/src/art-support" "$STAGE/tools/compat" "$STAGE/scripts"
cp -R "$ARCHIVE/src/translation-layer/." "$STAGE/translation-layer/"
cp -R "$ARCHIVE/src/translation-layer-next/." "$STAGE/translation-layer-next/"
# These are source inputs for a later isolated Strata adapter, not Xcode target
# membership. App entry-point code is kept in host-reference and never compiled.
for file in TranslationLayer.swift TLUnityView.swift TLAppSettings.swift AppWindows.swift HuskGamepad.swift HuskFilePicker.swift; do
  cp "$ARCHIVE/src/app/Husk/$file" "$STAGE/host-runtime/$file"
done
cp "$ARCHIVE/src/app/Husk/HuskApp.swift" "$STAGE/host-reference/HuskApp.swift"
# QEMU guest audio, keyboard and mixed QEMU/JIT log helpers are references only;
# they are not part of the native translation-layer host adapter.
for file in HuskAudio.swift HuskKeyboard.swift HuskLog.swift; do
  cp "$ARCHIVE/src/app/Husk/$file" "$STAGE/host-reference/$file"
done
# Audit-only: this bridge also declares QEMU/JIT APIs and references Husk-only pairing headers.
# Strata must create its own translation-layer bridge rather than compile this wholesale.
cp "$ARCHIVE/src/app/Husk/HuskBridge.h" "$STAGE/host-reference/HuskBridge.h"
cp "$ARCHIVE/src/app/project.yml" "$STAGE/build-support/project.yml"
cp "$ARCHIVE/src/app/Husk/Resources/cacert.pem" "$STAGE/resources/cacert.pem"
cp -R "$ARCHIVE/src/java-framework/." "$STAGE/src/java-framework/"
cp -R "$ARCHIVE/src/art-support/." "$STAGE/src/art-support/"
cp "$ARCHIVE/tools/strip_framework_res.py" "$STAGE/tools/strip_framework_res.py"
cp -R "$ARCHIVE/tools/compat/." "$STAGE/tools/compat/"
cp "$ARCHIVE/scripts/copy_aosp_bundle.sh" "$STAGE/scripts/copy_aosp_bundle.sh"
# Do not vendor interpreter caches as source.
find "$STAGE/src/java-framework" "$STAGE/tools/compat" -type d -name __pycache__ -prune -exec rm -rf {} +
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
Native sources: src/translation-layer and src/translation-layer-next
Native host candidates (reference only until adapted): src/app/Husk/{TranslationLayer,TLUnityView,TLAppSettings,AppWindows,HuskGamepad,HuskFilePicker}.swift
QEMU/mixed-host references only: src/app/Husk/{HuskAudio,HuskKeyboard,HuskLog}.swift
Host app entry point (reference only, never compile into Strata): src/app/Husk/HuskApp.swift
Original QEMU/JIT bridging header (reference only, never compile wholesale): src/app/Husk/HuskBridge.h
Upstream XcodeGen build manifest (audit reference only): src/app/project.yml
Runtime resource: src/app/Husk/Resources/cacert.pem
Build recipes: scripts/{build_java_runtime,build_android_system,build_angle_ios,build_art_support}.sh
Technical docs: docs/{00-architecture,01-licensing,04-translation-layer,05-translation-layer-milestone2-handoff}.md
Import date: $(date -u +%Y-%m-%d)
Method: git archive from the exact pinned commit
EOF

LEGACY_COUNT="$(find "$STAGE/translation-layer" -type f | wc -l | tr -d ' ')"
NATIVE_COUNT="$(find "$STAGE/translation-layer-next" -type f | wc -l | tr -d ' ')"
HOST_COUNT="$(find "$STAGE/host-runtime" -type f | wc -l | tr -d ' ')"
JAVA_COUNT="$(find "$STAGE/src/java-framework" -type f | wc -l | tr -d ' ')"
[[ "$LEGACY_COUNT" -gt 0 && "$NATIVE_COUNT" -gt 0 && "$HOST_COUNT" -gt 0 && "$JAVA_COUNT" -gt 0 ]] || { echo "Imported source groups are incomplete" >&2; exit 8; }

# Replace only importer-owned paths. Preserve INFINITY's
# Vendor/Husk/THIRD_PARTY_NOTICES.md and any other INFINITY-owned vendor files.
mkdir -p "$DEST"
for path in translation-layer translation-layer-next host-runtime host-reference build-support upstream-docs resources src/java-framework src/art-support tools scripts; do
  rm -rf "$DEST/$path"
  cp -R "$STAGE/$path" "$DEST/$path"
done
cp "$STAGE/HUSK-LICENSE" "$DEST/HUSK-LICENSE"
cp "$STAGE/UPSTREAM_REVISION.txt" "$DEST/UPSTREAM_REVISION.txt"

echo "[done] Imported $LEGACY_COUNT legacy-layer, $NATIVE_COUNT native-layer, $HOST_COUNT host-runtime and $JAVA_COUNT Java-framework files from Husk $REVISION"
echo "No Xcode target was changed. Complete dependency, licensing, and host-API review before compiling."
