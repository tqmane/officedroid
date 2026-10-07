#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$OFFICEDROID_ROOT"
mkdir -p .build/emulator "$ANDROID_AVD_HOME" "$HOME/.android"
if timeout 10s adb devices | grep -q '^emulator-5554'; then
    echo 'emulator-5554 is already in use; leave the existing emulator untouched.' >&2
    exit 1
fi
if ! avdmanager list avd -c | grep -qx officedroid-tablet; then
    printf 'no\n' | avdmanager create avd --name officedroid-tablet \
        --package 'system-images;android-36;google_apis;x86_64'
fi
accel=auto
boot_timeout=600
if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
    accel=off
    boot_timeout=1800
fi
emulator -avd officedroid-tablet -port 5554 -no-window -no-audio -no-boot-anim -no-snapshot \
    -gpu swiftshader_indirect -accel "$accel" -cores 2 -memory 3072 \
    > .build/emulator/emulator.log 2>&1 &
emulator_pid=$!
export ANDROID_SERIAL=emulator-5554
cleanup() {
    timeout 10s adb logcat -d > .build/emulator/logcat.txt 2>&1 || true
    timeout 10s adb shell screencap -p /sdcard/officedroid.png >/dev/null 2>&1 && timeout 10s adb pull /sdcard/officedroid.png .build/emulator/screenshot.png >/dev/null 2>&1 || true
    kill "$emulator_pid" 2>/dev/null || true
}
trap cleanup EXIT
deadline=$((SECONDS + ${EMULATOR_BOOT_TIMEOUT:-$boot_timeout}))
while [[ $(timeout 5s adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r') != 1 ]]; do
    kill -0 "$emulator_pid" || { tail -80 .build/emulator/emulator.log; exit 1; }
    ((SECONDS < deadline)) || { echo 'Emulator boot timeout' >&2; exit 1; }
    sleep 2
done
adb shell wm size 2560x1600
adb shell wm density 240
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb shell input keyevent 82
gradle --no-daemon :app:connectedDebugAndroidTest "$@"
# Keep a visible launcher screen in the diagnostic screenshot.
adb shell am start -n org.officedroid/.MainActivity
