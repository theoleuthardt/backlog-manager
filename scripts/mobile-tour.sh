#!/usr/bin/env bash
# Runs the mobile tour (#576) on the running Android emulator from app/:
# shapes the emulator like the device of TOUR_DEVICE (the logical size of the
# device at a lower pixel density, which the software GPU of the emulator
# keeps up with), lets it reach the backend on localhost:8000, drives the tour
# and then checks with native screenshots that a D-pad press leaves the look
# of the app as it is.
set -euo pipefail

device="${TOUR_DEVICE:?phone or handheld}"
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

flutter drive \
  --driver=test_driver/tour_driver.dart \
  --target=integration_test/mobile_tour_test.dart \
  -d emulator-5554 \
  --dart-define=TOUR_DEVICE="$device" \
  --dart-define=TOUR_PASSWORD="$INITIAL_ADMIN_PASSWORD" \
  || echo "flutter drive failed with $?" >> "$out/drive-failed.txt"

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
