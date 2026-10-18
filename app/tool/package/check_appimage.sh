#!/usr/bin/env bash
# Fails when the AppImage holds anything but the Flutter release bundle and the
# files of the AppImage itself: a system library inside it (the WebKitGTK tree
# of the build machine, once) takes the place of the one of the system the app
# runs on and keeps it from starting. Usage: check_appimage.sh [file].
set -euo pipefail

cd "$(dirname "$0")/../.."
bundle=$PWD/build/linux/x64/release/bundle
image=${1:-$(ls "$PWD"/dist/*/Backlog-Manager_*_linux_x64.AppImage | head -1)}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

(cd "$work" && APPIMAGE_EXTRACT_AND_RUN=1 "$image" --appimage-extract > /dev/null)
extra=$(diff \
  <(cd "$bundle" && find . -type f | sort) \
  <(cd "$work/squashfs-root" && find . -type f ! -name AppRun ! -name backlog_manager.desktop ! -name backlog_manager.png | sort) \
  || true)
if [ -n "$extra" ]; then
  echo "the AppImage differs from the release bundle:" >&2
  echo "$extra" >&2
  exit 1
fi
echo "AppImage ok: only the release bundle and the files of the AppImage ($(du -h "$image" | cut -f1))"
