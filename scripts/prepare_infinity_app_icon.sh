#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Branding/INFINITY-AppIcon.svg"
DEST="$ROOT/Resources/Assets.xcassets/AppIcon.appiconset"

if [[ ! -s "$SOURCE" ]]; then
  echo "error: canonical INFINITY icon source is missing: $SOURCE" >&2
  exit 1
fi

if ! command -v rsvg-convert >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "error: rsvg-convert is required to render the canonical app icon" >&2
    exit 1
  fi
  brew install librsvg
fi

mkdir -p "$DEST"
for filename in "AppIcon1024.png" "AppIconDark1024.png" "AppIconDark1024 1.png"; do
  rsvg-convert --format=png --width=1024 --height=1024 "$SOURCE" --output="$DEST/$filename"
  dimensions="$(sips -g pixelWidth -g pixelHeight "$DEST/$filename" | awk '/pixelWidth|pixelHeight/ {print $2}' | tr '\n' ' ')"
  if [[ "$dimensions" != "1024 1024 " ]]; then
    echo "error: rendered icon has invalid dimensions ($dimensions): $filename" >&2
    exit 1
  fi
  file "$DEST/$filename"
done

echo "Canonical INFINITY app icon rendered and validated (1024x1024)."
