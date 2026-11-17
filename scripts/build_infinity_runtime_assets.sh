#!/usr/bin/env bash
# Build the native Android translation-layer runtime payload from the pinned
# Lineage system image. This never builds, signs or exports an IPA.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${1:?usage: build_infinity_runtime_assets.sh <lineage-vda.qcow2> [output-dir]}"
OUT="${2:-$ROOT/build/infinity-runtime-assets}"
JDK="${HUSK_JDK:-${JAVA_HOME:-}}"
D8="${HUSK_D8:-}"

for command_name in qemu-img gpt debugfs unzip python3 zip shasum; do
    command -v "$command_name" >/dev/null 2>&1 || {
        echo "error: required tool not found: $command_name" >&2
        exit 2
    }
done
[[ -f "$IMAGE" ]] || { echo "error: image not found: $IMAGE" >&2; exit 2; }
[[ -n "$JDK" && -x "$JDK/bin/javac" && -x "$JDK/bin/java" && -x "$JDK/bin/jar" ]] || {
    echo "error: set HUSK_JDK or JAVA_HOME to a full JDK (javac/java/jar required)" >&2
    exit 2
}
[[ -n "$D8" && -f "$D8" ]] || {
    echo "error: set HUSK_D8 to the pinned R8/D8 jar (8.5 or newer)" >&2
    exit 2
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
RAW="$WORK/vda.raw"
SYSTEM_IMG="$WORK/system.img"
SYSTEM_DUMP="$WORK/system-dump"
SYSTEM_APEX="$SYSTEM_DUMP/apex"
APEX_ROOT="$WORK/apex"
HUSK_ROOT="$WORK/husk-source"
mkdir -p "$SYSTEM_DUMP" "$APEX_ROOT" "$HUSK_ROOT"

echo "==> Converting the Lineage qcow2 image"
qemu-img convert -O raw "$IMAGE" "$RAW"

echo "==> Extracting the Android system logical partition"
python3 - "$RAW" "$SYSTEM_IMG" <<'PY'
import os, struct, subprocess, sys

raw, output = sys.argv[1:3]
listing = subprocess.run(["gpt", "-r", "show", raw], check=True,
                         capture_output=True, text=True).stdout
starts = []
for line in listing.splitlines():
    fields = line.split()
    if len(fields) >= 4 and fields[2:4] == ["2", "GPT"]:
        starts.append(int(fields[0]))
if not starts:
    raise SystemExit("could not locate the super partition in the GPT")
base = starts[0] * 512

with open(raw, "rb") as disk:
    disk.seek(base + 12288)
    header = disk.read(256)
    magic, _, _, header_size = struct.unpack_from("<IHHI", header, 0)
    if magic != 0x414C5030:
        raise SystemExit("super partition has no Android logical-partition metadata")
    offset = 12 + 32
    table_size = struct.unpack_from("<I", header, offset)[0]
    offset += 4 + 32
    descriptors = [struct.unpack_from("<III", header, offset + 12 * i) for i in range(4)]
    disk.seek(base + 12288 + header_size)
    table = disk.read(table_size)
    (part_offset, part_count, part_size), (extent_offset, extent_count, extent_size) = descriptors[:2]
    extents = [struct.unpack_from("<QIQI", table, extent_offset + extent_size * i)
               for i in range(extent_count)]

    found = False
    with open(output, "wb") as out:
        for index in range(part_count):
            entry = table[part_offset + part_size * index:part_offset + part_size * (index + 1)]
            name = entry[:36].split(b"\0", 1)[0].decode("utf-8", "replace")
            _, first_extent, extent_count_for_partition, _ = struct.unpack_from("<IIII", entry, 36)
            if name != "system":
                continue
            found = True
            for extent_index in range(first_extent, first_extent + extent_count_for_partition):
                sectors, _, data_sector, _ = extents[extent_index]
                disk.seek(base + data_sector * 512)
                remaining = sectors * 512
                while remaining:
                    chunk = disk.read(min(remaining, 64 << 20))
                    if not chunk:
                        raise SystemExit("unexpected end of image while extracting system partition")
                    out.write(chunk)
                    remaining -= len(chunk)
    if not found:
        raise SystemExit("Android system logical partition was not found")
if os.path.getsize(output) == 0:
    raise SystemExit("extracted system partition is empty")
print("system partition:", os.path.getsize(output), "bytes")
PY

DEBUGFS="$(command -v debugfs || true)"
if [[ -z "$DEBUGFS" && -x /opt/homebrew/opt/e2fsprogs/sbin/debugfs ]]; then
    DEBUGFS=/opt/homebrew/opt/e2fsprogs/sbin/debugfs
fi
[[ -n "$DEBUGFS" ]] || { echo "error: debugfs from e2fsprogs is required" >&2; exit 2; }

echo "==> Extracting APEX modules and platform framework resources"
"$DEBUGFS" -R "rdump /system/apex $SYSTEM_DUMP" "$SYSTEM_IMG" >/dev/null
"$DEBUGFS" -R "dump /system/framework/framework-res.apk $WORK/framework-res.apk" "$SYSTEM_IMG" >/dev/null
"$DEBUGFS" -R "dump /system/framework/org.apache.http.legacy.jar $WORK/org.apache.http.legacy.jar" "$SYSTEM_IMG" >/dev/null

extract_apex() {
    local module="$1"
    local archive=""
    for extension in apex capex; do
        if [[ -f "$SYSTEM_APEX/$module.$extension" ]]; then
            archive="$SYSTEM_APEX/$module.$extension"
            break
        fi
    done
    [[ -n "$archive" ]] || { echo "error: missing $module APEX in the Lineage image" >&2; exit 3; }

    local payload="$WORK/$module-apex-payload.img"
    python3 - "$archive" "$payload" <<'PY'
import io, sys, zipfile
source, output = sys.argv[1:3]
with zipfile.ZipFile(source) as archive:
    if "original_apex" in archive.namelist():
        with zipfile.ZipFile(io.BytesIO(archive.read("original_apex"))) as original:
            payload = original.read("apex_payload.img")
    else:
        payload = archive.read("apex_payload.img")
with open(output, "wb") as stream:
    stream.write(payload)
PY
    mkdir -p "$APEX_ROOT/$module"
    "$DEBUGFS" -R "rdump / $APEX_ROOT/$module" "$payload" >/dev/null
}

for module in com.android.art com.android.i18n com.android.tzdata com.android.conscrypt; do
    echo "  - $module"
    extract_apex "$module"
done

echo "==> Preparing matching Android system fonts, certificates and font maps"
ANDROID_SYSTEM="$WORK/husk-source/build/android-system"
mkdir -p "$ANDROID_SYSTEM/fonts" "$ANDROID_SYSTEM/etc" "$ANDROID_SYSTEM/cacerts"
mkdir -p "$SYSTEM_DUMP"
"$DEBUGFS" -R "rdump /system/fonts $SYSTEM_DUMP" "$SYSTEM_IMG" >/dev/null
find "$WORK/system-dump/fonts" -type f ! -name '*CJK*' -size +100c -exec cp {} "$ANDROID_SYSTEM/fonts/" \\;
"$DEBUGFS" -R "dump /system/etc/fonts.xml $ANDROID_SYSTEM/etc/fonts.xml" "$SYSTEM_IMG" >/dev/null
"$DEBUGFS" -R "dump /system/etc/font_fallback.xml $ANDROID_SYSTEM/etc/font_fallback.xml" "$SYSTEM_IMG" >/dev/null
if [[ -d "$APEX_ROOT/com.android.conscrypt/cacerts" ]]; then
    cp -R "$APEX_ROOT/com.android.conscrypt/cacerts/." "$ANDROID_SYSTEM/cacerts/"
else
    echo "error: Conscrypt APEX has no cacerts directory" >&2
    exit 3
fi
# Preserve the image's Android/AOSP notice when present; this bundle is not
# redistributed until its full third-party notice set has been reviewed.
mkdir -p "$WORK/husk-source/build/android-system/licenses"
"$DEBUGFS" -R "dump /system/etc/NOTICE.html.gz $WORK/husk-source/build/android-system/licenses/NOTICE.html.gz" "$SYSTEM_IMG" >/dev/null 2>&1 || true

echo "==> Preparing an isolated source workspace"
# Only the pinned vendor snapshot is needed for the asset build. Do not copy
# the whole INFINITY checkout (especially .git, SideStore or Xcode project files).
tar -C "$ROOT/Vendor/Husk" --exclude='./build' --exclude='./.build' -cf - . | tar -C "$HUSK_ROOT" -xf -

echo "==> Building Java framework DEX and runtime APEX layout"
HUSK_JDK="$JDK" HUSK_D8="$D8" HUSK_AOSP=0 \
HTTP_LEGACY="$WORK/org.apache.http.legacy.jar" \
FRAMEWORK_RES="$WORK/framework-res.apk" \
"$HUSK_ROOT/build-support/build_java_runtime.sh" "$APEX_ROOT"

echo "==> Validating runtime bundle"
python3 - "$HUSK_ROOT/build/java-runtime" "$HUSK_ROOT/build/android-system" <<'PY'
import os, sys
java, system = sys.argv[1:3]
files = [
    "com.android.art/javalib/core-oj.jar",
    "com.android.art/javalib/core-libart.jar",
    "com.android.art/javalib/okhttp.jar",
    "com.android.art/javalib/bouncycastle.jar",
    "com.android.art/javalib/apache-xml.jar",
    "com.android.art/lib64/libandroidio.so",
    "com.android.art/lib64/libbase.so",
    "com.android.art/lib64/libc++.so",
    "com.android.art/lib64/libexpat.so",
    "com.android.art/lib64/libjavacore.so",
    "com.android.art/lib64/libnativehelper.so",
    "com.android.art/lib64/libopenjdk.so",
    "com.android.i18n/javalib/core-icu4j.jar",
    "com.android.conscrypt/javalib/conscrypt.jar",
    "com.android.conscrypt/lib64/libjavacrypto.so",
    "com.android.conscrypt/lib64/libcrypto.so",
    "com.android.conscrypt/lib64/libssl.so",
    "husk-framework.dex",
    "husk-framework-core.dex",
    "org.apache.http.legacy.jar",
    "framework-res.apk",
]
missing = [p for p in files if not os.path.isfile(os.path.join(java, p))]
for p in ("com.android.i18n/etc/icu", "com.android.tzdata/etc"):
    if not os.path.isdir(os.path.join(java, p)):
        missing.append(p + "/")
for p in ("fonts", "etc", "cacerts"):
    if not os.path.isdir(os.path.join(system, p)):
        missing.append("android-system/" + p + "/")
for p in ("etc/fonts.xml", "etc/font_fallback.xml"):
    if not os.path.isfile(os.path.join(system, p)):
        missing.append("android-system/" + p)
if missing:
    raise SystemExit("runtime bundle incomplete:\\n  " + "\\n  ".join(missing))
print("Java runtime and Android system assets validated")
PY

rm -rf "$OUT/java-runtime" "$OUT/android-system" "$OUT/art-support" "$OUT/cacert.pem" "$OUT/runtime-assets-manifest.json" "$OUT/infinity-android-runtime-assets.zip"
mkdir -p "$OUT"
cp -R "$HUSK_ROOT/build/java-runtime" "$OUT/java-runtime"
cp -R "$HUSK_ROOT/build/android-system" "$OUT/android-system"
cp "$HUSK_ROOT/resources/cacert.pem" "$OUT/cacert.pem"

if [[ -n "${ANDROID_NDK:-}" ]]; then
    echo "==> Building optional Android guest ART support libraries"
    "$HUSK_ROOT/build-support/build_art_support.sh" "$OUT/art-support"
fi

IMAGE_SHA="$(shasum -a 256 "$IMAGE" | awk '{print $1}')"
JDK_VERSION="$("$JDK/bin/java" -version 2>&1 | head -n 1)"
D8_VERSION="$(basename "$D8")"
HUSK_REVISION="$(grep '^Revision:' "$ROOT/Vendor/Husk/UPSTREAM_REVISION.txt" | cut -d' ' -f2)"
python3 - "$OUT/runtime-assets-manifest.json" "$IMAGE_SHA" "$JDK_VERSION" "$D8_VERSION" "$HUSK_REVISION" "$IMAGE" <<'PY'
import datetime, json, os, sys
output, digest, jdk, d8, revision, image = sys.argv[1:]
data = {
    "format": 1,
    "upstream": "https://github.com/Leviidev/Husk",
    "husk_revision": revision,
    "source_image": os.path.basename(image),
    "source_image_sha256": digest,
    "jdk": jdk,
    "d8": d8,
    "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "runtime_payloads": ["java-runtime/", "android-system/", "cacert.pem"],
    "optional_payloads": ["art-support/"],
    "qemu_guest_included": False,
    "ipa_included": False
}
with open(output, "w", encoding="utf-8") as stream:
    json.dump(data, stream, indent=2)
    stream.write("\\n")
PY

echo "==> Packaging runtime data (no QEMU guest image, no IPA)"
(
    cd "$OUT"
    zip -qr "infinity-android-runtime-assets.zip" java-runtime android-system cacert.pem runtime-assets-manifest.json \
        $(if [[ -d art-support ]]; then printf '%s' art-support; fi)
    unzip -t "infinity-android-runtime-assets.zip" >/dev/null
)
echo "Runtime assets ready:"
du -sh "$OUT/java-runtime" "$OUT/android-system" "$OUT/infinity-android-runtime-assets.zip"
echo "SHA-256: $(shasum -a 256 "$OUT/infinity-android-runtime-assets.zip" | awk '{print $1}')"
