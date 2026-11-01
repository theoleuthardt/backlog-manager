#!/usr/bin/env bash
# Runs the mobile tour (#576) on the running Android emulator
# (scripts/android-emulator.sh) from app/: builds the app with the tour, shapes
# the emulator like the device of TOUR_DEVICE (the logical size of the device
# at a lower pixel density), lets it reach the backend on localhost:8000,
# drives the tour and then takes native screenshots around a D-pad press, which
# show whether the look of the app changes. The screenshots, the report and the
# logcat of the run go to tour/<device>/.
set -euo pipefail

device="${TOUR_DEVICE:?phone or handheld}"
apk=build/app/outputs/flutter-apk/app-debug.apk
out="tour/$device"
mkdir -p "$out"

flutter build apk --debug \
  --target=integration_test/mobile_tour_test.dart \
  --dart-define=TOUR_DEVICE="$device" \
  --dart-define=TOUR_PASSWORD="$INITIAL_ADMIN_PASSWORD"

adb reverse tcp:8000 tcp:8000
if [ "$device" = handheld ]; then
  adb shell wm size 720x1280
  adb shell wm density 240
else
  adb shell wm size 720x1560
  adb shell wm density 280
fi
sleep 3

adb logcat -c
adb logcat -v time > "$out/logcat.txt" 2>&1 &
logcat=$!
trap 'kill "$logcat" 2> /dev/null || true' EXIT

flutter drive \
  --driver=test_driver/tour_driver.dart \
  --target=integration_test/mobile_tour_test.dart \
  --use-application-binary="$apk" \
  -d emulator-5554 \
  || echo "flutter drive failed with $?" >> "$out/drive-failed.txt"

adb install -r "$apk" > /dev/null
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
