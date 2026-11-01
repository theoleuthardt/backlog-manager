#!/usr/bin/env bash
# Starts the Android emulator AVD (default tour, or the first argument) without
# a screen and waits for its boot. It renders with Mesa llvmpipe under Xvfb,
# because SwiftShader, the software GPU that comes with the emulator, crashes
# within minutes of drawing the app (#588). Needs /dev/kvm, Xvfb and the Mesa
# drivers (libgl1-mesa-dri, libglx-mesa0).
set -euo pipefail

avd="${1:-tour}"
display=:99

pgrep Xvfb > /dev/null || {
  setsid nohup Xvfb "$display" -screen 0 1280x1024x24 +extension GLX > /dev/null 2>&1 < /dev/null &
  sleep 2
}

DISPLAY="$display" LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
  setsid nohup emulator -avd "$avd" -no-snapshot -noaudio -no-boot-anim -camera-back none -gpu host \
  > /tmp/android-emulator.log 2>&1 < /dev/null &

for _ in $(seq 1 150); do
  [ "$(adb shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" = 1 ] && exit 0
  sleep 2
done
echo "The emulator did not boot, see /tmp/android-emulator.log" >&2
exit 1
