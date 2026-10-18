#!/usr/bin/env bash
# Builds the AppImage from the Flutter release bundle: the app, its own plugin
# libraries and nothing else. No system library goes in (Fastforge put every
# library `ldd` finds into it, the WebKitGTK tree of the build machine too,
# and that did not run on a system with other library versions); WebKitGTK 4.1
# and libsoup 3 are a requirement of the system, like for the deb and the rpm.
set -euo pipefail

cd "$(dirname "$0")/../.."
full_version=$(sed -n 's/^version: *\([^ ]*\).*/\1/p' pubspec.yaml)
version=${full_version%%+*}
bundle=$PWD/build/linux/x64/release/bundle
dist=$PWD/dist/$full_version
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

[ -x "$bundle/backlog_manager" ] || { echo "no release bundle in $bundle, run flutter build linux first" >&2; exit 1; }

appdir=$work/AppDir
mkdir -p "$appdir" "$dist"
cp -a "$bundle"/. "$appdir"/
install -m 0755 linux/packaging/appimage/AppRun "$appdir/AppRun"
cp linux/packaging/appimage/backlog_manager.desktop "$appdir/backlog_manager.desktop"
cp linux/packaging/icon.png "$appdir/backlog_manager.png"

out="$dist/Backlog-Manager_${version}_linux_x64.AppImage"
ARCH=x86_64 appimagetool --no-appstream "$appdir" "$out"
echo "Successfully packaged $out"
