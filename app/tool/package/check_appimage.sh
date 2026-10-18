#!/usr/bin/env bash
# Fails when the AppImage holds anything but the Flutter release bundle and the
# files of the AppImage itself: a system library inside it (the WebKitGTK tree
# of the build machine, once) takes the place of the one of the system the app
# runs on and keeps it from starting. The files, their contents and the
# symlinks are compared with the bundle. Usage: check_appimage.sh [file]; by
# default the newest AppImage in dist.
set -euo pipefail

cd "$(dirname "$0")/../.."
bundle=$PWD/build/linux/x64/release/bundle
image=${1:-$(ls -t "$PWD"/dist/*/Backlog-Manager_*_linux_x64.AppImage | head -1)}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

(cd "$work" && APPIMAGE_EXTRACT_AND_RUN=1 "$image" --appimage-extract > /dev/null)
if ! extra=$(diff -r \
  -x AppRun -x backlog_manager.desktop -x backlog_manager.png -x .DirIcon \
  "$bundle" "$work/squashfs-root" 2>&1); then
  echo "the AppImage differs from the release bundle:" >&2
  echo "$extra" >&2
  exit 1
fi
echo "AppImage ok: only the release bundle and the files of the AppImage ($(du -h "$image" | cut -f1))"
