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
