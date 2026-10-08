#!/usr/bin/env bash
# Build the real Kerberos/GSSAPI provider needed by Office's App-V RPC server.
set -euo pipefail
source "$(dirname "$0")/env.sh"
abi=${1:-x86_64}
case "$abi" in
    x86_64) target=x86_64-linux-android ;;
    arm64-v8a) target=aarch64-linux-android ;;
    *) echo 'Usage: build-kerberos.sh {x86_64|arm64-v8a}' >&2; exit 2 ;;
esac
version=1.22.2
build="$OFFICEDROID_ROOT/.build"
archive="$OFFICEDROID_TOOLS/downloads/krb5-$version.tar.gz"
mkdir -p "$build" "$(dirname "$archive")"
exec 9>"$build/kerberos-source.lock"
flock 9
if [[ ! -f $archive ]]; then
    curl --fail --location --retry 3 "https://kerberos.org/dist/krb5/1.22/krb5-$version.tar.gz" -o "$archive.part"
    mv "$archive.part" "$archive"
fi
echo "3243ffbc8ea4d4ac22ddc7dd2a1dc54c57874c40648b60ff97009763554eaf13  $archive" | sha256sum -c -
patch_id=$(cat "$OFFICEDROID_ROOT"/patches/krb5/*.patch | sha256sum | cut -d' ' -f1)
source_dir="$build/krb5-source-$version-${patch_id:0:16}"
if [[ ! -f $source_dir/.officedroid-patched ]]; then
    temporary=$(mktemp -d "$build/krb5-source-tmp.XXXXXX")
    tar -xf "$archive" -C "$temporary" --strip-components=1
    for fix in "$OFFICEDROID_ROOT"/patches/krb5/*.patch; do patch -d "$temporary" -p1 < "$fix"; done
    touch "$temporary/.officedroid-patched"
    mv "$temporary" "$source_dir"
fi
flock -u 9
deps="$build/deps-$abi"
ndkbin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
mkdir -p "$build/krb5-$abi"
cd "$build/krb5-$abi"
CC="$ndkbin/${target}29-clang" AR="$ndkbin/llvm-ar" RANLIB="$ndkbin/llvm-ranlib" \
    CFLAGS='-O2 -g -fPIC' LDFLAGS='-Wl,-z,max-page-size=16384' LIBS=-landroid \
    krb5_cv_attr_constructor_destructor='yes,yes' ac_cv_func_regcomp=yes ac_cv_printf_positional=yes \
    "$source_dir/src/configure" --build="$(gcc -dumpmachine)" --host="$target" \
    --prefix="$deps" --disable-static --enable-shared --disable-rpath --disable-nls \
    --without-keyutils --without-libedit --without-system-verto --with-crypto-impl=builtin --disable-pkinit
# Build libraries and their generators; the APK does not need KDC daemons or CLI clients.
make all-prerecurse
for directory in util include lib build-tools; do
    make -C "$directory" -j "${JOBS:-4}"
done
make install-mkdirs
for directory in util include lib build-tools; do
    make -C "$directory" install
done
mkdir -p "$deps/share/licenses/krb5"
cp "$source_dir/NOTICE" "$deps/share/licenses/krb5/NOTICE"
