#!/usr/bin/env bash
# Source this from any working directory. All downloaded tools stay in the checkout.
OFFICEDROID_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export OFFICEDROID_ROOT
export OFFICEDROID_TOOLS="${OFFICEDROID_TOOLS:-$OFFICEDROID_ROOT/.tools}"
export ANDROID_HOME="$OFFICEDROID_TOOLS/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/28.2.13676358"
export GRADLE_USER_HOME="$OFFICEDROID_TOOLS/gradle-home"
export ANDROID_USER_HOME="$OFFICEDROID_TOOLS/android-user"
export ANDROID_AVD_HOME="$ANDROID_USER_HOME/avd"
export PATH="$OFFICEDROID_TOOLS/gradle-8.13/bin:$ANDROID_HOME/cmdline-tools/19.0/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmake/3.22.1/bin:$OFFICEDROID_TOOLS/llvm-mingw/bin:$PATH"
if [[ -d "$OFFICEDROID_TOOLS/host/usr" ]]; then
    export PATH="$OFFICEDROID_TOOLS/host/usr/bin:$PATH"
    if [[ -x "$OFFICEDROID_TOOLS/host/usr/lib/jvm/java-21-openjdk-$(dpkg --print-architecture)/bin/javac" ]]; then
        export JAVA_HOME="$OFFICEDROID_TOOLS/host/usr/lib/jvm/java-21-openjdk-$(dpkg --print-architecture)"
        export PATH="$JAVA_HOME/bin:$PATH"
    fi
    export BISON_PKGDATADIR="$OFFICEDROID_TOOLS/host/usr/share/bison"
    export M4="$OFFICEDROID_TOOLS/host/usr/bin/m4"
fi
