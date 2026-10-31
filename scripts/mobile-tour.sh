#!/usr/bin/env bash
# Runs the mobile tour (#576) on the running Android emulator from app/:
# shapes the emulator like the device of TOUR_DEVICE (the logical size of the
# device at a lower pixel density, which the software GPU of the emulator
# keeps up with), lets it reach the backend on localhost:8000, drives the tour
# with the app the workflow built before the emulator started (TOUR_APK, so
# the Gradle and Kotlin daemons no longer share the memory of the runner with
# the emulator) and then checks with native screenshots that a D-pad press
# leaves the look of the app as it is. The logcat of the run and, when the
# drive fails, the free memory, the end of the kernel log and the emulator
# process go to the
# report folder.
set -euo pipefail

device="${TOUR_DEVICE:?phone or handheld}"
apk="${TOUR_APK:-build/app/outputs/flutter-apk/app-debug.apk}"
out="tour/$device"
mkdir -p "$out"

adb reverse tcp:8000 tcp:8000
adb shell settings put system accelerometer_rotation 0
if [ "$device" = handheld ]; then
  adb shell wm size 720x1280
  adb shell wm density 240
  adb shell settings put system user_rotation 1
else
  adb shell wm size 720x1560
  adb shell wm density 280
  adb shell settings put system user_rotation 0
fi
sleep 3

adb logcat -c
adb logcat -v time > "$out/logcat.txt" 2>&1 &
logcat=$!

flutter drive \
  --driver=test_driver/tour_driver.dart \
  --target=integration_test/mobile_tour_test.dart \
  --use-application-binary="$apk" \
  -d emulator-5554 \
  || echo "flutter drive failed with $?" >> "$out/drive-failed.txt"

kill "$logcat" 2> /dev/null || true
if [ -f "$out/drive-failed.txt" ]; then
  {
    free -m
    sudo dmesg | tail -60
    pgrep -a -f qemu-system || echo "no emulator process"
  } > "$out/memory.txt" 2>&1 || true
fi

adb shell am force-stop dev.theocloud.blm || true
adb shell monkey -p dev.theocloud.blm -c android.intent.category.LAUNCHER 1 > /dev/null
sleep 20
adb exec-out screencap -p > "$out/native_1_before_dpad.png"
adb shell input keyevent KEYCODE_DPAD_DOWN
sleep 2
adb exec-out screencap -p > "$out/native_2_after_dpad.png"
adb shell input keyevent KEYCODE_DPAD_DOWN
adb shell input keyevent KEYCODE_BUTTON_A
sleep 2
adb exec-out screencap -p > "$out/native_3_after_a.png"

if [ -f "$out/drive-failed.txt" ]; then
  cat "$out/drive-failed.txt"
  exit 1
fi
