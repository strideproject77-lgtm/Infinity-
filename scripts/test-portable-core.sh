#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

for tool in clang swiftc; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: $tool is required" >&2
    exit 1
  fi
done

echo "==> Checking portable C APK archive implementation"
clang -std=c11 -D_DEFAULT_SOURCE -Wall -Wextra -fsyntax-only \
  -I LiveContainerSwiftUI/Strata3 \
  LiveContainerSwiftUI/Strata3/INFINITYAPKArchive.c

echo "==> Checking exported C bridge headers"
printf '%s\n' \
  '#include "INFINITYAPKArchive.h"' \
  '#include "INFINITYHuskRuntimeBridge.h"' \
  | clang -x c -std=c11 -fsyntax-only \
      -I LiveContainerSwiftUI/Strata3 \
      -I Vendor/Husk/include -

echo "==> Type-checking Foundation-only Swift APK parsers"
swiftc -typecheck \
  LiveContainerSwiftUI/Strata3/INFINITYAPKManifest.swift \
  LiveContainerSwiftUI/Strata3/INFINITYAPKInspection.swift

echo "Portable core checks passed on $(uname -s) / $(uname -m)"
