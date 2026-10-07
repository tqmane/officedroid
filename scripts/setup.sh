#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
wine=false
emulator=false
for arg in "$@"; do
    case "$arg" in
        --wine) wine=true ;;
        --emulator) emulator=true ;;
        *) echo "Usage: $0 [--wine] [--emulator]" >&2; exit 2 ;;
    esac
done
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || {
    echo 'Android SDK/NDK host tools require Linux x86_64; both Android target ABIs are built here.' >&2
    exit 1
}
mkdir -p "$OFFICEDROID_TOOLS/downloads" "$ANDROID_USER_HOME" "$GRADLE_USER_HOME"
mkdir -p "$GRADLE_USER_HOME/init.d"
cp "$OFFICEDROID_ROOT/scripts/gradle-network.init.gradle" "$GRADLE_USER_HOME/init.d/officedroid-network.gradle"
packages=()
java_major=$(javac -version 2>&1 | sed -n 's/^javac \([0-9]*\).*/\1/p' || true)
if [[ -z $java_major ]] || ((java_major < 17)); then
    packages+=(openjdk-21-jdk-headless openjdk-21-jre-headless)
fi
for dependency in gcc:build-essential g++:build-essential make:build-essential pkg-config:pkg-config curl:curl git:git unzip:unzip python3:python3 patch:patch flock:util-linux; do
    command -v "${dependency%%:*}" >/dev/null || packages+=("${dependency#*:}")
done
if $emulator; then
    command -v tesseract >/dev/null || packages+=(tesseract-ocr tesseract-ocr-eng)
fi
if $wine; then
    for tool in bison flex m4; do command -v "$tool" >/dev/null || packages+=("$tool"); done
fi
if ((${#packages[@]})); then
    if [[ $EUID == 0 ]] || command -v sudo >/dev/null; then
        root=(); [[ $EUID == 0 ]] || root=(sudo)
        "${root[@]}" apt-get update
        "${root[@]}" apt-get install -y --no-install-recommends "${packages[@]}"
    else
        # Read-only cloud image: authenticated APT downloads, extracted without root.
        source /etc/os-release
        [[ $ID == debian ]] || { echo 'Rootless installation currently supports Debian; use sudo apt on Ubuntu.' >&2; exit 1; }
        aptdir="$OFFICEDROID_TOOLS/apt"
        mkdir -p "$aptdir/lists/partial" "$aptdir/archives/partial" "$OFFICEDROID_TOOLS/host"
        printf 'deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://deb.debian.org/debian %s main\n' "$VERSION_CODENAME" > "$aptdir/sources.list"
        cat > "$aptdir/config" <<EOF
Dir::Etc::parts "-";
Dir::Etc::main "-";
Dir::Etc::sourcelist "$aptdir/sources.list";
Dir::Etc::sourceparts "-";
Dir::State::lists "$aptdir/lists";
Dir::Cache::archives "$aptdir/archives";
Dir::Cache::pkgcache "";
Dir::Cache::srcpkgcache "";
Debug::NoLocking "true";
APT::Sandbox::User "$(id -un)";
EOF
        APT_CONFIG="$aptdir/config" /usr/bin/apt-get update
        APT_CONFIG="$aptdir/config" /usr/bin/apt-get --download-only --reinstall --no-install-recommends -y install "${packages[@]}"
        for deb in "$aptdir/archives/"*.deb; do dpkg-deb -x "$deb" "$OFFICEDROID_TOOLS/host"; done
        source "$(dirname "$0")/env.sh"
    fi
fi
download() {
    local url=$1 file=$2 hash=$3 algorithm=$4
    if [[ ! -f $file ]] || ! printf '%s  %s\n' "$hash" "$file" | "${algorithm}sum" --check --status; then
        curl --fail --location --retry 3 --show-error "$url" -o "$file.part"
        printf '%s  %s\n' "$hash" "$file.part" | "${algorithm}sum" --check
        mv "$file.part" "$file"
    fi
}
if [[ ! -x $ANDROID_HOME/cmdline-tools/19.0/bin/sdkmanager ]]; then
    zip="$OFFICEDROID_TOOLS/downloads/commandlinetools-19.0.zip"
    download https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip "$zip" 5fdcc763663eefb86a5b8879697aa6088b041e70 sha1
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    unzip -q -o "$zip" -d "$ANDROID_HOME/cmdline-tools"
    mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/19.0"
fi
if [[ ! -x $OFFICEDROID_TOOLS/gradle-8.13/bin/gradle ]]; then
    zip="$OFFICEDROID_TOOLS/downloads/gradle-8.13-bin.zip"
    download https://services.gradle.org/distributions/gradle-8.13-bin.zip "$zip" 20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78 sha256
    unzip -q -o "$zip" -d "$OFFICEDROID_TOOLS"
fi
# Preserve sdkmanager's status; yes may finish with SIGPIPE after the consumer exits.
set +o pipefail
yes 2>/dev/null | python3 "$OFFICEDROID_ROOT/scripts/sdkmanager.py" --sdk_root="$ANDROID_HOME" --licenses > "$OFFICEDROID_TOOLS/android-licenses.log"
status=${PIPESTATUS[1]}
set -o pipefail
((status == 0)) || exit "$status"
python3 "$OFFICEDROID_ROOT/scripts/sdkmanager.py" --sdk_root="$ANDROID_HOME" 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' 'ndk;28.2.13676358' 'cmake;3.22.1'
if $emulator; then
    python3 "$OFFICEDROID_ROOT/scripts/sdkmanager.py" --sdk_root="$ANDROID_HOME" 'emulator' 'system-images;android-36;google_apis;x86_64'
fi
if $wine && [[ ! -x $OFFICEDROID_TOOLS/llvm-mingw/bin/x86_64-w64-mingw32-clang ]]; then
    archive="$OFFICEDROID_TOOLS/downloads/llvm-mingw-20250709.tar.xz"
    download https://github.com/mstorsjo/llvm-mingw/releases/download/20250709/llvm-mingw-20250709-ucrt-ubuntu-22.04-x86_64.tar.xz "$archive" 60cafae6474c7411174cff1d4ba21a8e46cadbaeb05a1bace306add301628337 sha256
    mkdir -p "$OFFICEDROID_TOOLS/llvm-mingw"
    tar -xf "$archive" --strip-components=1 -C "$OFFICEDROID_TOOLS/llvm-mingw"
fi
javac -version
gradle --version
"$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" --version
echo "Setup complete. Source scripts/env.sh before invoking tools directly."
