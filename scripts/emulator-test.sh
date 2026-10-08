#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$OFFICEDROID_ROOT"
if [[ ${OFFICEDROID_KEEP_EMULATOR:-0} == 1 && -z ${GITHUB_ENV:-} ]]; then
    echo 'Keeping the emulator requires GitHub Actions teardown steps.' >&2
    exit 1
fi
mkdir -p .build/emulator "$ANDROID_AVD_HOME" "$HOME/.android"
if timeout 10s adb devices | grep -q '^emulator-5554'; then
    echo 'emulator-5554 is already in use; leave the existing emulator untouched.' >&2
    exit 1
fi
# ARM64 is the device target even when the cross-build host is x86_64.
# Keep the build SDK in this shell for Gradle; the boot helper isolates its AVD SDK.
bash scripts/setup-arm64-emulator.sh
python3 scripts/android-arm64-boot.py --keep-running --timeout-seconds "${EMULATOR_BOOT_TIMEOUT:-1800}"
emulator_pid=$(python3 -c 'import json; print(json.load(open(".build/arm64-boot/result.json"))["emulator_pid"])')
boot_timeout=1800
export ANDROID_SERIAL=emulator-5554
logcat_pid=
cleanup() {
    "$OFFICEDROID_ROOT/scripts/emulator-stop.sh" "$emulator_pid" "$logcat_pid"
}
trap cleanup EXIT
for attempt in 1 2; do
    deadline=$((SECONDS + ${EMULATOR_BOOT_TIMEOUT:-$boot_timeout}))
    while [[ $(timeout 5s adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r') != 1 ]]; do
        kill -0 "$emulator_pid" || { tail -80 .build/arm64-boot/emulator.log; exit 1; }
        ((SECONDS < deadline)) || { echo 'Emulator boot timeout' >&2; exit 1; }
        sleep 2
    done
    adb shell settings put system accelerometer_rotation 0
    adb shell settings put system user_rotation 0
    adb shell wm dismiss-keyguard
    if python3 scripts/emulator-ready.py ".build/emulator/boot-$attempt.xml"; then
        break
    fi
    adb logcat -d > ".build/emulator/boot-$attempt-logcat.txt"
    adb exec-out screencap -p > ".build/emulator/boot-$attempt.png"
    ((attempt == 1)) || exit 1
    # Retry only Android's initial setup, before any APK or application test.
    # Retain the initialized system data; all application data is still fresh.
    echo 'Android startup failed; recording evidence and rebooting once before APK installation.'
    adb reboot
    timeout 30s adb wait-for-disconnect
done
# Initial System UI startup competes with package initialization on CI hosts.
# Boot at a smaller tablet resolution, then require a stable home screen again
# at the actual Office test resolution before installing any application.
adb shell wm size 2560x1600
adb shell wm density 240
python3 scripts/emulator-ready.py .build/emulator/boot-test-resolution.xml
# Keep evidence even if the device disconnects during a graphics failure.
adb logcat -v threadtime -b main -b system -b crash > .build/emulator/live-logcat.txt 2>&1 &
logcat_pid=$!
exec 8>.build/android-build.lock
flock 8
instrumentation_status=0
gradle --no-daemon :app:connectedDebugAndroidTest \
    -Pandroid.injected.androidTest.leaveApksInstalledAfterRun=true "$@" || instrumentation_status=$?
# Keep the freshly tested prefix for GUI/Office, avoiding a second wineboot.
# Reinstall only if instrumentation did not leave the APK installed. Updating
# an installed APK changes nativeLibraryDir and forces runtime re-extraction.
if ! adb shell pm path org.officedroid | grep -q '^package:'; then
    timeout 120s adb install -r app/build/outputs/apk/debug/app-debug.apk
fi
launch_args=()
for arg in "$@"; do
    [[ $arg != -PwineRuntime=true ]] || launch_args+=(--wine)
done
python3 scripts/launch-test.py "${launch_args[@]}"
if ((${#launch_args[@]})); then
    gui_status=0
    python3 scripts/wine-gui-test.py || gui_status=$?
    # Collect independent GUI evidence even if a networking check failed.
    ((instrumentation_status == 0)) || exit "$instrumentation_status"
    ((gui_status == 0)) || exit "$gui_status"
    python3 scripts/wine-gui-test.py --wow64
    if [[ ${OFFICEDROID_KEEP_EMULATOR:-0} == 1 ]]; then
        # Subsequent CI steps use this tested prefix and expose each Office gate.
        # Publish PIDs only after every runtime check passed; failures clean up here.
        printf 'OFFICEDROID_EMULATOR_PID=%s\nOFFICEDROID_LOGCAT_PID=%s\n' \
            "$emulator_pid" "$logcat_pid" >> "$GITHUB_ENV"
        trap - EXIT
    else
        python3 scripts/office-install-test.py --timeout-seconds "${OFFICE_INSTALL_TIMEOUT_SECONDS:-1800}"
        python3 scripts/office-edit-test.py
    fi
fi
exit "$instrumentation_status"
