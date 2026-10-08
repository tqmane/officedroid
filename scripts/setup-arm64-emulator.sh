#!/usr/bin/env bash
set -euo pipefail
case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) host=mac ;;
    Linux-x86_64) host=linux ;;
    *) echo 'Use ARM64 macOS or x86_64 Linux to emulate ARM64 Android.' >&2; exit 1 ;;
esac
root=$(cd "$(dirname "$0")/.." && pwd)
sdk="$root/.tools/android-arm64-sdk"
downloads="$root/.tools/downloads"
mkdir -p "$sdk" "$downloads"
install_archive() {
    local url=$1 hash=$2 destination=$3 archive="$downloads/${1##*/}"
    if [[ ! -f $archive ]] || ! echo "$hash  $archive" | shasum -a 1 --check --status; then
        curl --fail --location --retry 3 "$url" -o "$archive.part"
        echo "$hash  $archive.part" | shasum -a 1 --check
        mv "$archive.part" "$archive"
    fi
    mkdir -p "$destination"
    unzip -qo "$archive" -d "$destination"
}
# Checksums are from Google's repository2-3.xml and sys-img/android/sys-img2-3.xml.
if [[ $host == mac ]]; then
    install_archive https://dl.google.com/android/repository/emulator-darwin_aarch64-16428233.zip \
        3af4fe44ce82b3d88ae5678a53735f27ad729c15 "$sdk"
    install_archive https://dl.google.com/android/repository/platform-tools_r37.0.1-darwin.zip \
        6ae73f4de6452dc57e62ec02b68eed92a4c21661 "$sdk"
    install_archive https://dl.google.com/android/repository/commandlinetools-mac-13114758_latest.zip \
        c3e06a1959762e89167d1cbaa988605f6f7c1d24 "$sdk/cmdline-tools/19.0-tmp"
else
    if [[ $(dpkg-query -W -f='${db:Status-Status}' libpulse0 2>/dev/null || true) != installed ]]; then
        sudo apt-get update
        sudo apt-get install -y --no-install-recommends libpulse0
    fi
    install_archive https://dl.google.com/android/repository/emulator-linux_x64-16428233.zip \
        cd7362ea55dfb86a418958138dc396e74165dd01 "$sdk"
    install_archive https://dl.google.com/android/repository/platform-tools_r37.0.1-linux.zip \
        477254aa5f903c15cf51001717bdf347fb6b53e0 "$sdk"
    install_archive https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip \
        5fdcc763663eefb86a5b8879697aa6088b041e70 "$sdk/cmdline-tools/19.0-tmp"
fi
# Manually extracted emulator archives lack SDK Manager's local package record.
# avdmanager requires that record even when the emulator executable is present.
cat > "$sdk/emulator/package.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<repo:repository xmlns:repo="http://schemas.android.com/repository/android/common/02"
 xmlns:generic="http://schemas.android.com/repository/android/generic/02"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
 <localPackage path="emulator" obsolete="false">
  <type-details xsi:type="generic:genericDetailsType"/>
  <revision><major>37</major><minor>2</minor><micro>12</micro></revision>
  <display-name>Android Emulator</display-name>
 </localPackage>
</repo:repository>
EOF
mkdir -p "$sdk/cmdline-tools/19.0"
cp -R "$sdk/cmdline-tools/19.0-tmp/cmdline-tools/." "$sdk/cmdline-tools/19.0/"
export ANDROID_HOME="$sdk" ANDROID_SDK_ROOT="$sdk"
export ANDROID_USER_HOME="$root/.tools/android-arm64-user"
export ANDROID_AVD_HOME="$ANDROID_USER_HOME/avd"
mkdir -p "$ANDROID_AVD_HOME"
set +o pipefail
yes 2>/dev/null | "$sdk/cmdline-tools/19.0/bin/sdkmanager" --sdk_root="$sdk" --licenses > "$downloads/arm64-android-licenses.log"
status=${PIPESTATUS[1]}
set -o pipefail
((status == 0)) || exit "$status"
install_archive https://dl.google.com/android/repository/sys-img/android/arm64-v8a-36_r02.zip \
    62ad6714df790f89c8a8ad32552ffe20bb16fe87 "$sdk/system-images/android-36/default"
echo no | "$sdk/cmdline-tools/19.0/bin/avdmanager" create avd --force \
    --name officedroid-arm64 --package 'system-images;android-36;default;arm64-v8a'
cat >> "$ANDROID_AVD_HOME/officedroid-arm64.avd/config.ini" <<'EOF'
hw.lcd.width=800
hw.lcd.height=1280
hw.lcd.density=120
hw.initialOrientation=landscape
hw.keyboard=yes
showDeviceFrame=no
disk.dataPartition.size=24G
EOF
"$sdk/emulator/emulator" -version
