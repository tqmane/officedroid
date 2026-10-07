#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
abi=${1:-x86_64}
case "$abi" in
    x86_64) target=x86_64-linux-android; pe=x86_64 ;;
    arm64-v8a) target=aarch64-linux-android; pe=aarch64 ;;
    *) echo 'Usage: build-wine.sh {x86_64|arm64-v8a}' >&2; exit 2 ;;
esac
revision=db11d0fe6a169c457e23d007e20404643d067aa8
source_dir="$OFFICEDROID_TOOLS/src/wine"
build="$OFFICEDROID_ROOT/.build"
jobs=${JOBS:-4}
if [[ ! -d $source_dir ]]; then
    mkdir -p "$(dirname "$source_dir")"
    git clone --depth 1 --branch wine-11.0 https://github.com/wine-mirror/wine.git "$source_dir"
fi
[[ $(git -C "$source_dir" rev-parse HEAD) == "$revision" ]] || { echo 'Unexpected Wine revision' >&2; exit 1; }
[[ -z $(git -C "$source_dir" status --porcelain) ]] || { echo 'Wine source has local changes; preserve and inspect them first.' >&2; exit 1; }
mkdir -p "$build/wine-host" "$build/wine-$abi"
if [[ ! -f $build/wine-host/Makefile ]]; then
    (cd "$build/wine-host" && "$source_dir/configure" --enable-win64 --without-x --without-wayland --without-freetype)
fi
make -C "$build/wine-host" -j "$jobs" __tooldeps__
ndkbin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
if [[ ! -f $build/wine-$abi/Makefile ]]; then
    (cd "$build/wine-$abi" && \
        CC="$ndkbin/${target}29-clang" \
        CXX="$ndkbin/${target}29-clang++" \
        AR="$ndkbin/llvm-ar" RANLIB="$ndkbin/llvm-ranlib" \
        STRIP="$ndkbin/llvm-strip" \
        PKG_CONFIG_LIBDIR=/nonexistent \
        CFLAGS='-O2 -g' LDFLAGS='-Wl,-z,max-page-size=16384' \
        "$source_dir/configure" --host="$target" --enable-win64 --enable-archs="$pe" \
        --with-wine-tools="$build/wine-host" --prefix=/opt/officedroid \
        --without-x --without-wayland --without-dbus --without-pulse --without-alsa \
        --without-cups --without-pcap --without-udev --without-usb --without-v4l2 \
        --without-gstreamer --without-sdl --without-oss)
fi
make -C "$build/wine-$abi" -j "$jobs"
make -C "$build/wine-$abi" DESTDIR="$build/wine-install-$abi" install
"$ndkbin/llvm-readelf" --file-header "$build/wine-$abi/server/wineserver"
echo "Wine $abi built; Android execution still requires APK integration and device tests."
