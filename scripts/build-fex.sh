#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
export PATH="$OFFICEDROID_TOOLS/llvm-mingw-fex/bin:$PATH"
source_dir="$OFFICEDROID_TOOLS/src/fex"
revision=fa556167d5a64ec7adb5503c2aa15b169c292cac
if [[ ! -d $source_dir ]]; then
    mkdir -p "$source_dir"
    git -C "$source_dir" init
    git -C "$source_dir" remote add origin https://github.com/AndreRH/FEX.git
    git -C "$source_dir" fetch --depth 1 origin "$revision"
    git -C "$source_dir" checkout --detach FETCH_HEAD
fi
[[ $(git -C "$source_dir" rev-parse HEAD) == "$revision" ]] || { echo 'Unexpected FEX revision' >&2; exit 1; }
[[ -z $(git -C "$source_dir" status --porcelain) ]] || { echo 'FEX has local changes; preserve them first.' >&2; exit 1; }
# Build upstream unchanged. Exclude unrelated Linux rootfs/tests/thunks dependencies.
git -C "$source_dir" submodule update --init --depth 1 \
    External/fmt External/xxhash External/unordered_dense External/range-v3 \
    External/rpmalloc Source/Common/cpp-optparse
for architecture in aarch64 arm64ec; do
    target=wow64fex
    [[ $architecture != arm64ec ]] || target=arm64ecfex
    build="$OFFICEDROID_ROOT/.build/fex-$architecture"
    cmake -S "$source_dir" -B "$build" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$source_dir/Data/CMake/toolchain_mingw.cmake" \
        -DCMAKE_BUILD_TYPE=Release -DMINGW_TRIPLE="$architecture-w64-mingw32" \
        -DENABLE_LTO=OFF -DBUILD_TESTING=OFF -DENABLE_CCACHE=OFF \
        -DTUNE_CPU=generic -DTUNE_ARCH=generic
    cmake --build "$build" --target "$target" -j "${JOBS:-4}"
done
