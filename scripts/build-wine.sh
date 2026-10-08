#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
abi=${1:-x86_64}
case "$abi" in
    x86_64) target=x86_64-linux-android; pe=x86_64,i386 ;;
    arm64-v8a) target=aarch64-linux-android; pe=aarch64 ;;
    *) echo 'Usage: build-wine.sh {x86_64|arm64-v8a}' >&2; exit 2 ;;
esac
revision=db11d0fe6a169c457e23d007e20404643d067aa8
source_dir="$OFFICEDROID_TOOLS/src/wine"
build="$OFFICEDROID_ROOT/.build"
jobs=${JOBS:-4}
mkdir -p "$build"
# Host tools and source preparation are shared by both ABI builds.
exec 9>"$build/wine-prepare.lock"
flock 9
if [[ ! -d $source_dir ]]; then
    mkdir -p "$(dirname "$source_dir")"
    git clone --depth 1 --branch wine-11.0 https://github.com/wine-mirror/wine.git "$source_dir"
fi
[[ $(git -C "$source_dir" rev-parse HEAD) == "$revision" ]] || { echo 'Unexpected Wine revision' >&2; exit 1; }
[[ -z $(git -C "$source_dir" status --porcelain) ]] || { echo 'Wine source has local changes; preserve and inspect them first.' >&2; exit 1; }
patch_id=$(cat "$OFFICEDROID_ROOT"/patches/wine/*.patch | sha256sum | cut -d' ' -f1)
patched="$build/wine-source-${patch_id:0:16}"
if [[ ! -f $patched/.officedroid-patched ]]; then
    temporary=$(mktemp -d "$build/wine-source-tmp.XXXXXX")
    git -C "$source_dir" archive HEAD | tar -x -C "$temporary"
    for fix in "$OFFICEDROID_ROOT"/patches/wine/*.patch; do patch -d "$temporary" -p1 < "$fix"; done
    touch "$temporary/.officedroid-patched"
    mv "$temporary" "$patched"
fi
source_dir="$patched"
mkdir -p "$build/wine-host" "$build/wine-$abi"
ndkbin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
freetype="$OFFICEDROID_TOOLS/src/freetype"
if [[ ! -d $freetype ]]; then
    git clone --depth 1 --branch VER-2-13-3 https://github.com/freetype/freetype.git "$freetype"
fi
[[ $(git -C "$freetype" rev-parse HEAD) == 42608f77f20749dd6ddc9e0536788eaad70ea4b5 ]] || { echo 'Unexpected FreeType revision' >&2; exit 1; }
[[ -z $(git -C "$freetype" status --porcelain) ]] || { echo 'FreeType source has local changes' >&2; exit 1; }
# sfnt2fon is a host program and also needs FreeType, independently of target FreeType.
cmake -S "$freetype" -B "$build/freetype-host" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$build/deps-host" -DBUILD_SHARED_LIBS=ON \
    -DFT_DISABLE_ZLIB=ON -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_PNG=ON \
    -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON
cmake --build "$build/freetype-host" -j "$jobs"
cmake --install "$build/freetype-host"
(cd "$build/wine-host" && PKG_CONFIG_LIBDIR="$build/deps-host/lib/pkgconfig" \
    LDFLAGS="-Wl,-rpath,$build/deps-host/lib" \
    "$source_dir/configure" --enable-win64 --without-x --without-wayland)
make -C "$build/wine-host" -j "$jobs" __tooldeps__
flock -u 9
"$OFFICEDROID_ROOT/scripts/build-tls.sh" "$abi"
"$OFFICEDROID_ROOT/scripts/build-kerberos.sh" "$abi"
deps="$build/deps-$abi"
cmake -S "$freetype" -B "$build/freetype-$abi" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$abi" -DANDROID_PLATFORM=android-29 -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$deps" -DBUILD_SHARED_LIBS=ON \
    -DFT_DISABLE_ZLIB=ON -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_PNG=ON \
    -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON
cmake --build "$build/freetype-$abi" -j "$jobs"
cmake --install "$build/freetype-$abi"
# Reconfigure on each invocation so changed flags/source paths cannot reuse stale configuration.
    (cd "$build/wine-$abi" && \
        CC="$ndkbin/${target}29-clang" \
        CXX="$ndkbin/${target}29-clang++" \
        AR="$ndkbin/llvm-ar" RANLIB="$ndkbin/llvm-ranlib" \
        STRIP="$ndkbin/llvm-strip" \
        PKG_CONFIG=pkg-config PKG_CONFIG_LIBDIR="$deps/lib/pkgconfig" \
        RESOLV_LIBS=-landroid \
        CFLAGS='-O2 -g' LDFLAGS='-Wl,-z,max-page-size=16384' \
        "$source_dir/configure" --build="$(gcc -dumpmachine)" --host="$target" --enable-win64 --enable-archs="$pe" --disable-tests \
        --with-wine-tools="$build/wine-host" --prefix=/opt/officedroid \
        --without-x --without-wayland --without-dbus --without-pulse --without-alsa \
        --without-cups --without-pcap --without-udev --without-usb --without-v4l2 \
        --without-gstreamer --without-sdl --without-oss --with-gnutls --with-krb5 --with-gssapi)
make -C "$build/wine-$abi" -j "$jobs"
make -C "$build/wine-$abi" DESTDIR="$build/wine-install-$abi" install
"$ndkbin/llvm-readelf" --file-header "$build/wine-$abi/server/wineserver"
echo "Wine $abi built; Android execution still requires APK integration and device tests."
