#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source_svg=tool/icons/icon.svg
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sed 's/viewBox="0 0 1024 1024"/viewBox="100 100 824 824"/' "$source_svg" > "$work/full.svg"

for size in 16 32 64 128 256 512 1024; do
  rsvg-convert -w "$size" -h "$size" "$source_svg" \
    -o "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png"
done

for size in 16 24 32 48 64 128 256; do
  rsvg-convert -w "$size" -h "$size" "$work/full.svg" -o "$work/win_$size.png"
done
convert "$work"/win_16.png "$work"/win_24.png "$work"/win_32.png "$work"/win_48.png \
  "$work"/win_64.png "$work"/win_128.png "$work"/win_256.png windows/runner/resources/app_icon.ico

rsvg-convert -w 512 -h 512 "$work/full.svg" -o linux/packaging/icon.png
