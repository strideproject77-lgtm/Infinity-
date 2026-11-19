#!/bin/bash
# build_java_runtime.sh [apex-root] -- stage a complete, validated Java runtime for INFINITY/Husk.
# Inputs can be supplied explicitly or through HUSK_ANDROID_ROOT / ANDROID_APEX_ROOT.
set -euo pipefail

R="$(cd "$(dirname "$0")/.." && pwd)"
HUSK_ANDROID_ROOT="${HUSK_ANDROID_ROOT:-/Volumes/GTAV/husk2}"
APEX="${1:-${ANDROID_APEX_ROOT:-$HUSK_ANDROID_ROOT/root/apex}}"
JDK="${HUSK_JDK:-$HUSK_ANDROID_ROOT/tools-dl/jdk/Contents/Home}"
D8="${HUSK_D8:-$HUSK_ANDROID_ROOT/tools-dl/r8.jar}"
HTTP_LEGACY="${HTTP_LEGACY:-$HUSK_ANDROID_ROOT/modules/jars/org.apache.http.legacy.jar}"
FRAMEWORK_RES="${FRAMEWORK_RES:-$HUSK_ANDROID_ROOT/aosp/fw/framework-res.apk}"
ANDROID_SYSROOT="${ANDROID_SYSROOT:-$HUSK_ANDROID_ROOT/root/system}"
BUILD_ROOT="$R/build"
OUT="$BUILD_ROOT/java-runtime"

require_file() {
    if [ ! -f "$1" ] || [ ! -r "$1" ]; then
        echo "error: required runtime input is missing or unreadable: $1" >&2
        exit 2
    fi
}
require_dir() {
    if [ ! -d "$1" ] || [ ! -r "$1" ]; then
        echo "error: required runtime directory is missing or unreadable: $1" >&2
        exit 2
    fi
}

# Validate every mandatory input before touching the previous known-good output.
require_dir "$APEX"
require_dir "$APEX/com.android.i18n/etc/icu"
require_dir "$APEX/com.android.tzdata/etc"
require_file "$JDK/bin/javac"
require_file "$JDK/bin/java"
require_file "$JDK/bin/jar"
require_file "$D8"
require_file "$HTTP_LEGACY"
require_file "$FRAMEWORK_RES"

for j in core-oj core-libart okhttp bouncycastle apache-xml; do
    require_file "$APEX/com.android.art/javalib/$j.jar"
done
for l in libandroidio libbase libc++ libexpat libjavacore libnativehelper libopenjdk; do
    require_file "$APEX/com.android.art/lib64/$l.so"
done
require_file "$APEX/com.android.i18n/javalib/core-icu4j.jar"
for l in libjavacrypto libcrypto libssl; do
    require_file "$APEX/com.android.conscrypt/lib64/$l.so"
done
require_file "$APEX/com.android.conscrypt/javalib/conscrypt.jar"

mkdir -p "$BUILD_ROOT"
WORK="$(mktemp -d "$BUILD_ROOT/.java-runtime.XXXXXX")"
STAGED="$WORK/java-runtime"
OLD="$BUILD_ROOT/.java-runtime.previous.$$"
mkdir -p "$STAGED"
cleanup() {
    rm -rf "$WORK"
}
trap cleanup EXIT

copy() {
    mkdir -p "$STAGED/$(dirname "$1")"
    cp "$APEX/$1" "$STAGED/$1"
}

echo "==> staging Android ART, ICU, timezone and Conscrypt assets"
for j in core-oj core-libart okhttp bouncycastle apache-xml; do
    copy "com.android.art/javalib/$j.jar"
done
for l in libandroidio libbase libc++ libexpat libjavacore libnativehelper libopenjdk; do
    copy "com.android.art/lib64/$l.so"
done
copy "com.android.i18n/javalib/core-icu4j.jar"
# ICU native libraries vary slightly between Android releases; include those supplied by the image.
for l in libicu libicui18n libicuuc libicu_jni libandroidicu; do
    if [ -f "$APEX/com.android.i18n/lib64/$l.so" ]; then
        copy "com.android.i18n/lib64/$l.so"
    fi
done
mkdir -p "$STAGED/com.android.i18n/etc"
cp -R "$APEX/com.android.i18n/etc/icu" "$STAGED/com.android.i18n/etc/"
mkdir -p "$STAGED/com.android.tzdata"
cp -R "$APEX/com.android.tzdata/etc" "$STAGED/com.android.tzdata/"
copy "com.android.conscrypt/javalib/conscrypt.jar"
for l in libjavacrypto libcrypto libssl; do
    copy "com.android.conscrypt/lib64/$l.so"
done

echo "==> compiling Husk Java framework"
export HUSK_JDK="$JDK"
export HUSK_D8="$D8"
"$R/src/java-framework/build.sh" "$STAGED/husk-framework.dex"
require_file "$STAGED/husk-framework.dex"
require_file "$STAGED/husk-framework-core.dex"

cp "$HTTP_LEGACY" "$STAGED/org.apache.http.legacy.jar"
python3 "$R/tools/strip_framework_res.py" "$FRAMEWORK_RES" "$STAGED/framework-res.apk"
require_file "$STAGED/org.apache.http.legacy.jar"
require_file "$STAGED/framework-res.apk"

# AOSP jars are an optional augmentation. Husk's own framework remains the fallback.
if [ "${HUSK_AOSP:-1}" != "0" ]; then
    export ANDROID_SYSROOT
    "$R/scripts/copy_aosp_bundle.sh" "$ANDROID_SYSROOT" "$STAGED/aosp"
fi

# Promote only after every mandatory asset has been generated and checked. Keep the
# previous complete runtime available for rollback if the final rename fails.
rm -rf "$OLD"
if [ -e "$OUT" ]; then
    mv "$OUT" "$OLD"
fi
if ! mv "$STAGED" "$OUT"; then
    if [ -e "$OLD" ]; then mv "$OLD" "$OUT"; fi
    echo "error: could not promote staged Java runtime; previous runtime restored" >&2
    exit 1
fi
rm -rf "$OLD"
echo "==> installed validated Java runtime at $OUT"
du -sh "$OUT"
