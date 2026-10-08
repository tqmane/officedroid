#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$OFFICEDROID_ROOT"
export ANDROID_SERIAL=emulator-5554
mkdir -p .build/emulator
timeout 20s adb logcat -d -b main -b system -b crash -t 5000 > .build/emulator/logcat.txt 2>&1 || true
timeout 10s adb shell screencap -p /sdcard/officedroid.png >/dev/null 2>&1 && timeout 10s adb pull /sdcard/officedroid.png .build/emulator/screenshot.png >/dev/null 2>&1 || true
[[ -z ${2:-} ]] || kill "$2" 2>/dev/null || true
[[ -z ${1:-} ]] || kill "$1" 2>/dev/null || true
