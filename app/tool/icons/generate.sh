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

sed -e 's/viewBox="0 0 1024 1024"/viewBox="100 100 824 824"/' -e 's/ clip-path="url(#tile)"//' \
  "$source_svg" > "$work/square.svg"

ios_icons=ios/Runner/Assets.xcassets/AppIcon.appiconset
for entry in 20x20@1x:20 20x20@2x:40 20x20@3x:60 29x29@1x:29 29x29@2x:58 29x29@3x:87 \
  40x40@1x:40 40x40@2x:80 40x40@3x:120 60x60@2x:120 60x60@3x:180 76x76@1x:76 \
  76x76@2x:152 83.5x83.5@2x:167 1024x1024@1x:1024; do
  name=${entry%%:*}
  size=${entry##*:}
  rsvg-convert -w "$size" -h "$size" "$work/square.svg" -o "$work/ios.png"
  convert "$work/ios.png" -background black -alpha remove -alpha off "$ios_icons/Icon-App-$name.png"
done

android_res=android/app/src/main/res
for entry in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
  IFS=: read -r density legacy adaptive <<< "$entry"
  rsvg-convert -w "$legacy" -h "$legacy" "$work/full.svg" -o "$android_res/mipmap-$density/ic_launcher.png"
  safe=$((adaptive * 3 / 5))
  rsvg-convert -w "$safe" -h "$safe" "$work/square.svg" -o "$work/foreground.png"
  convert "$work/foreground.png" -background none -gravity center -extent "${adaptive}x${adaptive}" \
    "$android_res/mipmap-$density/ic_launcher_foreground.png"
done
