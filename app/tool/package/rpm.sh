#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
full_version=$(sed -n 's/^version: *\([^ ]*\).*/\1/p' pubspec.yaml)
version=${full_version%%+*}
bundle=$PWD/build/linux/x64/release/bundle
dist=$PWD/dist/$full_version
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$dist"
rpmbuild -bb linux/packaging/rpm/backlog-manager.spec \
  --define "_topdir $work" \
  --define "app_version $version" \
  --define "app_bundle $bundle" \
  --define "app_desktop $PWD/linux/packaging/rpm/backlog-manager.desktop" \
  --define "app_icon $PWD/linux/packaging/icon.png"

cp "$work"/RPMS/x86_64/backlog-manager-*.rpm "$dist/Backlog-Manager_${version}_linux_x64.rpm"
echo "Successfully packaged $dist/Backlog-Manager_${version}_linux_x64.rpm"
