#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$OFFICEDROID_ROOT"
mkdir -p .build
exec 8>.build/android-build.lock
flock 8
jobs=${JOBS:-4}
cmake -S runtime -B .build/native-host -G Ninja
cmake --build .build/native-host -j "$jobs"
ctest --test-dir .build/native-host --output-on-failure
for abi in x86_64 arm64-v8a; do
    cmake -S runtime -B ".build/native-$abi" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI="$abi" -DANDROID_PLATFORM=android-29
    cmake --build ".build/native-$abi" -j "$jobs"
    mkdir -p ".build/jniLibs/$abi"
    cp ".build/native-$abi/libodprobe.so" ".build/jniLibs/$abi/"
done
gradle --no-daemon :app:assembleDebug :app:assembleDebugAndroidTest :app:lintDebug "$@"
