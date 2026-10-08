#!/usr/bin/env bash
# Build Wine's TLS provider directly for Android/Bionic, with no external runtime.
set -euo pipefail
source "$(dirname "$0")/env.sh"
abi=${1:-x86_64}
case "$abi" in
    x86_64) target=x86_64-linux-android ;;
    arm64-v8a) target=aarch64-linux-android ;;
    *) echo 'Usage: build-tls.sh {x86_64|arm64-v8a}' >&2; exit 2 ;;
esac
build="$OFFICEDROID_ROOT/.build"
deps="$build/deps-$abi"
jobs=${JOBS:-4}
mkdir -p "$build" "$OFFICEDROID_TOOLS/downloads" "$OFFICEDROID_TOOLS/src"
exec 9>"$build/tls-source.lock"
flock 9
fetch_source() {
    local name=$1 url=$2 digest=$3 archive="$OFFICEDROID_TOOLS/downloads/${2##*/}"
    if [[ ! -f $archive ]]; then
        curl --fail --location --retry 3 "$url" -o "$archive.part"
        mv "$archive.part" "$archive"
    fi
    echo "$digest  $archive" | sha256sum -c -
    if [[ ! -d $OFFICEDROID_TOOLS/src/$name ]]; then
        tar -xf "$archive" -C "$OFFICEDROID_TOOLS/src"
    fi
}
fetch_source gmp-6.3.0 https://mirrors.kernel.org/gnu/gmp/gmp-6.3.0.tar.xz a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898
fetch_source nettle-3.10.2 https://mirrors.kernel.org/gnu/nettle/nettle-3.10.2.tar.gz fe9ff51cb1f2abb5e65a6b8c10a92da0ab5ab6eaf26e7fc2b675c45f1fb519b5
fetch_source gnutls-3.8.13 https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz ffed8ec1bf09c2426d4f14aae377de4753b53e537d685e604e99a8b16ca9c97e
flock -u 9
ndkbin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
export CC="$ndkbin/${target}29-clang" CXX="$ndkbin/${target}29-clang++"
export AR="$ndkbin/llvm-ar" RANLIB="$ndkbin/llvm-ranlib" STRIP="$ndkbin/llvm-strip"
export CFLAGS='-O2 -g -fPIC -DNO_INLINE_GETPASS=1'
export CPPFLAGS="-I$deps/include" LDFLAGS="-L$deps/lib -Wl,-z,max-page-size=16384"
export PKG_CONFIG_LIBDIR="$deps/lib/pkgconfig"
compile() {
    local name=$1
    shift
    mkdir -p "$build/$name-$abi"
    (cd "$build/$name-$abi"
     "$OFFICEDROID_TOOLS/src/$name/configure" --build="$(gcc -dumpmachine)" --host="$target" \
        --prefix="$deps" --enable-shared --disable-static "$@"
     make -j "$jobs"
     make install)
}
compile gmp-6.3.0 --disable-cxx --disable-assembly
compile nettle-3.10.2 --disable-documentation --disable-assembler
compile gnutls-3.8.13 --disable-tools --disable-cxx --disable-tests --disable-doc --disable-guile \
    --disable-hardware-acceleration --disable-openssl-compatibility --disable-nls \
    --with-included-libtasn1 --with-included-unistring --without-idn --without-p11-kit \
    --without-zlib --without-brotli --without-zstd \
    --with-default-trust-store-dir=/apex/com.android.conscrypt/cacerts
