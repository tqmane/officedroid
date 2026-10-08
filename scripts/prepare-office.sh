#!/usr/bin/env bash
# Fetch Microsoft's ODT for local/device experiments. Never package these files in an APK.
set -euo pipefail
source "$(dirname "$0")/env.sh"
[[ $# == 0 || ( $# == 1 && $1 == --media ) ]] || {
    echo 'Usage: prepare-office.sh [--media]' >&2
    exit 2
}
mkdir -p "$OFFICEDROID_TOOLS/downloads/office" "$OFFICEDROID_ROOT/.build/office"
fetch() {
    local url=$1 file=$2 sha=$3
    if [[ ! -f $file ]] || ! printf '%s  %s\n' "$sha" "$file" | sha256sum --check --status; then
        curl --fail --location --retry 3 --retry-all-errors --show-error "$url" -o "$file.part"
        printf '%s  %s\n' "$sha" "$file.part" | sha256sum --check
        mv "$file.part" "$file"
    fi
}
case $(uname -m) in
    x86_64) sevenzip_arch=x64; sevenzip_sha=4ca3b7c6f2f67866b92622818b58233dc70367be2f36b498eb0bdeaaa44b53f4 ;;
    aarch64) sevenzip_arch=arm64; sevenzip_sha=39c5140f02ce4436599303c59a149f654cb1bbc47cdc105a942120d747ae040d ;;
    *) echo 'Office media preparation requires Linux x86_64 or ARM64' >&2; exit 1 ;;
esac
sevenzip="$OFFICEDROID_TOOLS/7zip-$sevenzip_arch/7zzs"
archive="$OFFICEDROID_TOOLS/downloads/7z2501-linux-$sevenzip_arch.tar.xz"
if [[ ! -x $sevenzip ]]; then
    fetch "https://www.7-zip.org/a/7z2501-linux-$sevenzip_arch.tar.xz" "$archive" "$sevenzip_sha"
    mkdir -p "$(dirname "$sevenzip")"
    tar -xf "$archive" -C "$(dirname "$sevenzip")"
fi
odt="$OFFICEDROID_TOOLS/downloads/office/odt-20326-20112.exe"
fetch https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_20326-20112.exe "$odt" \
    fbb64358fd4168acd52ee4efe47ffd032b6231dfb415ae2dce61b0e58ba67f86
# The bundled sample XML carries a Windows reparse stream; use our own config.
"$sevenzip" x -tCab "$odt" setup.exe EULA -o"$OFFICEDROID_ROOT/.build/office/odt" -y
test -s "$OFFICEDROID_ROOT/.build/office/odt/setup.exe"
file "$OFFICEDROID_ROOT/.build/office/odt/setup.exe"
# Click-to-Run imports modern MSVC exception handlers absent from Wine's CRT.
# Install Microsoft's complete redistributables in the prefix, never in the APK.
fetch https://download.visualstudio.microsoft.com/download/pr/bd1c8d9d-ba95-4eee-bc6e-df1fcc876373/CC0FF0EB1DC3F5188AE6300FAEF32BF5BEEBA4BDD6E8E445A9184072096B713B/VC_redist.x64.exe \
    "$OFFICEDROID_TOOLS/downloads/office/vc-redist-x64.exe" \
    cc0ff0eb1dc3f5188ae6300faef32bf5beeba4bdd6e8e445a9184072096b713b
fetch https://download.visualstudio.microsoft.com/download/pr/bd1c8d9d-ba95-4eee-bc6e-df1fcc876373/0C09F2611660441084CE0DF425C51C11E147E6447963C3690F97E0B25C55ED64/VC_redist.x86.exe \
    "$OFFICEDROID_TOOLS/downloads/office/vc-redist-x86.exe" \
    0c09f2611660441084ce0df425c51c11e147e6447963c3690f97e0b25c55ed64
for arch in x64 x86; do
    cp "$OFFICEDROID_TOOLS/downloads/office/vc-redist-$arch.exe" \
        "$OFFICEDROID_ROOT/.build/office/odt/vc_redist.$arch.exe"
done
# App-V's manifest merge fails with Wine's MSXML implementation. Prepare the
# official MSXML6 SP2 security update for prefix-local native DLL installation.
# The amd64 Microsoft package also contains the i386 DLLs.
msxml="$OFFICEDROID_TOOLS/downloads/office/msxml6-KB2957482-enu-amd64.exe"
fetch https://download.microsoft.com/download/2/7/7/277681BE-4048-4A58-ABBA-259C465B1699/msxml6-KB2957482-enu-amd64.exe "$msxml" \
    260cd870851ffc3c6d10b71691f134e20d8d03ac26073bb36951eacb7aa85897
xml_stage="$OFFICEDROID_ROOT/.build/office/msxml6"
"$sevenzip" e -tCab "$msxml" msxml6.msi -o"$xml_stage" -y
"$sevenzip" e "$xml_stage/msxml6.msi" 'msxml6.dll.*' 'msxml6r.dll.*' -o"$xml_stage/extracted" -y
for arch in x64 x86; do
    suffix=1ECC0691_D2EB_4A33_9CBF_5487E5CB17DB
    [[ $arch != x86 ]] || suffix=86F857F6_A743_463D_B2FE_98CB5F727E09
    mkdir -p "$xml_stage/$arch"
    for name in msxml6 msxml6r; do
        cp "$xml_stage/extracted/$name.dll.$suffix" "$xml_stage/$arch/$name.dll"
    done
done
if [[ ${1:-} == --media ]]; then
    # Prepare Microsoft's normal Office/Data source layout for offline ODT.
    # Symlinks avoid duplicating the 3.3 GB cache in this host workspace.
    version=16.0.20430.20146
    base=https://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60/Office/Data
    cache="$OFFICEDROID_TOOLS/downloads/office"
    media="$OFFICEDROID_ROOT/.build/office/media/Office/Data"
    mkdir -p "$media/$version"
    fetch "$base/v64_$version.cab" "$cache/v64_$version.cab" \
        9b6b9abad01baf204385b1b907b086c07f390b95377350cac7a90ed44ca19eae
    ln -sfn "$cache/v64_$version.cab" "$media/v64_$version.cab"
    ln -sfn "$cache/v64_$version.cab" "$media/v64.cab"
    while read -r name sha; do
        fetch "$base/$version/$name" "$cache/$name" "$sha"
        ln -sfn "$cache/$name" "$media/$version/$name"
    done <<'CAB_HASHES'
i640.cab b3b985aa9df5181244abadee856ae369bcc2516ab2a93afa5f1112f72b60259c
i641033.cab b2fc7ba21559ddcdbd11e5ed7afb152980223916aae096fc6d19f4c160387bae
s640.cab dac554dbd741d71e3b488449afef445cd8015816dabc59524258426356ee7077
s641033.cab d73a721f7c5eac3449b507137f9560778b8c94d137ef7b11b9e361f36bc9e010
CAB_HASHES
    for culture in x-none en-us; do
        cab=s640.cab
        [[ $culture != en-us ]] || cab=s641033.cab
        name="stream.x64.$culture"
        # Each pinned Microsoft metadata CAB supplies the full DAT SHA-256.
        "$sevenzip" e -so "$cache/$cab" "$name.hash" \
            > "$OFFICEDROID_ROOT/.build/office/$name.hash"
        sha=$(python3 - "$OFFICEDROID_ROOT/.build/office/$name.hash" <<'READ_HASH'
from pathlib import Path
import re
import sys
value = Path(sys.argv[1]).read_bytes().decode('utf-16le').strip().lower()
assert re.fullmatch('[0-9a-f]{64}', value), 'Invalid Microsoft stream hash'
print(value)
READ_HASH
        )
        fetch "$base/$version/$name.dat" "$cache/$name.dat" "$sha"
        ln -sfn "$cache/$name.dat" "$media/$version/$name.dat"
    done
    echo "Official Office media verified: $media"
fi
