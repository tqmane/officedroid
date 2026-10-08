#!/usr/bin/env bash
# Fetch Microsoft's ODT for local/device experiments. Never package these files in an APK.
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$OFFICEDROID_TOOLS/downloads/office" "$OFFICEDROID_ROOT/.build/office"
fetch() {
    local url=$1 file=$2 sha=$3
    if [[ ! -f $file ]] || ! printf '%s  %s\n' "$sha" "$file" | sha256sum --check --status; then
        curl --fail --location --retry 3 --show-error "$url" -o "$file.part"
        printf '%s  %s\n' "$sha" "$file.part" | sha256sum --check
        mv "$file.part" "$file"
    fi
}
archive="$OFFICEDROID_TOOLS/downloads/7z2501-linux-x64.tar.xz"
if [[ ! -x $OFFICEDROID_TOOLS/7zip/7zzs ]]; then
    fetch https://www.7-zip.org/a/7z2501-linux-x64.tar.xz "$archive" \
        4ca3b7c6f2f67866b92622818b58233dc70367be2f36b498eb0bdeaaa44b53f4
    mkdir -p "$OFFICEDROID_TOOLS/7zip"
    tar -xf "$archive" -C "$OFFICEDROID_TOOLS/7zip"
fi
odt="$OFFICEDROID_TOOLS/downloads/office/odt-20326-20112.exe"
fetch https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_20326-20112.exe "$odt" \
    fbb64358fd4168acd52ee4efe47ffd032b6231dfb415ae2dce61b0e58ba67f86
# The bundled sample XML carries a Windows reparse stream; use our own config.
"$OFFICEDROID_TOOLS/7zip/7zzs" x -tCab "$odt" setup.exe EULA -o"$OFFICEDROID_ROOT/.build/office/odt" -y
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
