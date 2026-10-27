#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
full_version=$(sed -n 's/^version: *\([^ ]*\).*/\1/p' pubspec.yaml)
version=${full_version%%+*}
[ -n "$version" ] || { echo "no version in pubspec.yaml" >&2; exit 1; }
app=$PWD/build/ios/iphoneos/Runner.app
dist=$PWD/dist/$full_version
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

[ -d "$app" ] || { echo "no release build in $app, run flutter build ios --release --no-codesign first" >&2; exit 1; }

mkdir -p "$work/Payload" "$dist"
cp -R "$app" "$work/Payload/"
out="$dist/Backlog-Manager_${version}_ios.ipa"
rm -f "$out"
(cd "$work" && zip -qr -y "$out" Payload)
echo "Successfully packaged $out"
