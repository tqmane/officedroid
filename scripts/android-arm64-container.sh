#!/usr/bin/env bash
# Evaluate native ARM64 Android test infrastructure on a standard Linux runner.
# This container is CI infrastructure, never part of the application runtime.
set -euo pipefail
[[ $# == 0 || ( $# == 1 && $1 == --stop ) ]] || exit 2
if [[ ${OFFICEDROID_KEEP_CONTAINER:-0} == 1 && -z ${GITHUB_ENV:-} ]]; then
    echo 'Keeping the Android container requires GitHub Actions teardown steps.' >&2
    exit 1
fi
[[ $(uname -s) == Linux && $(uname -m) == aarch64 ]]
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
output=.build/arm64-container
mkdir -p "$output"
uname -a > "$output/host.txt"
image=redroid/redroid@sha256:e194edc99aa364358d1f8c214acb18b6d006c74fa0561f39259a20173ec30b66
name=officedroid-arm64-boot
cleanup() {
    docker logs "$name" > "$output/container.log" 2>&1 || true
    timeout 20s adb -s 127.0.0.1:5555 logcat -b all -d > "$output/logcat.txt" 2>&1 || true
    sudo dmesg > "$output/dmesg.txt" 2>&1 || true
    docker rm -f "$name" >/dev/null 2>&1 || true
}
if [[ ${1:-} == --stop ]]; then
    cleanup
    exit
fi
if docker container inspect "$name" >/dev/null 2>&1; then
    echo 'The dedicated container name is already in use; leave it untouched.' >&2
    exit 1
fi
trap cleanup EXIT
packages=()
command -v adb >/dev/null || packages+=(adb)
if ! modinfo binder_linux > "$output/binder-module.txt" 2>&1; then
    packages+=("linux-modules-extra-$(uname -r)")
fi
if ((${#packages[@]})); then
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends "${packages[@]}"
fi
sudo modprobe binder_linux devices=binder,hwbinder,vndbinder
docker pull --platform linux/arm64 "$image"
docker image inspect "$image" > "$output/image.json"
docker run --platform linux/arm64 -d --privileged --name "$name" \
    -p 127.0.0.1:5555:5555 "$image" androidboot.use_memfd=true \
    androidboot.redroid_width=1280 androidboot.redroid_height=800 androidboot.redroid_dpi=160 \
    androidboot.redroid_gpu_mode=guest
python3 - <<'PY'
import json
from pathlib import Path
import subprocess
import time
output = Path('.build/arm64-container')
result = {'containerized': True, 'boot_completed': False, 'expected_abi': 'arm64-v8a'}
start = time.monotonic()
def adb(*args):
    return subprocess.check_output(['adb', '-s', '127.0.0.1:5555', *args], timeout=20, stderr=subprocess.STDOUT)
try:
    while time.monotonic() - start < 600:
        subprocess.run(['adb', 'connect', '127.0.0.1:5555'], timeout=20, capture_output=True)
        try:
            # Android 16's optional shader warmup crashes in drawHolePunchLayer
            # with redroid's software gralloc. SurfaceFlinger reads this AOSP
            # property on its next automatic restart; normal rendering remains
            # enabled and must produce the screenshot below.
            if not result.get('shader_warmup_disabled'):
                adb('shell', 'setprop', 'service.sf.prime_shader_cache', 'false')
                result['shader_warmup_disabled'] = (
                    adb('shell', 'getprop', 'service.sf.prime_shader_cache').strip() == b'false'
                )
            if adb('shell', 'getprop', 'sys.boot_completed').strip() == b'1':
                result['actual_abi'] = adb('shell', 'getprop', 'ro.product.cpu.abi').decode().strip()
                result['sdk'] = adb('shell', 'getprop', 'ro.build.version.sdk').decode().strip()
                result['selinux'] = adb('shell', 'getenforce').decode().strip()
                assert result['actual_abi'] == 'arm64-v8a' and result['sdk'] == '36', result
                (output / 'properties.txt').write_bytes(adb('shell', 'getprop'))
                (output / 'boot.png').write_bytes(adb('exec-out', 'screencap', '-p'))
                result['boot_completed'] = True
                break
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            pass
        time.sleep(5)
    if not result['boot_completed']:
        raise TimeoutError('Native ARM64 Android container did not complete boot in 600 seconds')
except Exception as error:
    result['error'] = str(error)
    raise
finally:
    result['elapsed_seconds'] = round(time.monotonic() - start, 1)
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
PY
if [[ ${OFFICEDROID_KEEP_CONTAINER:-0} == 1 ]]; then
    printf 'OFFICEDROID_CONTAINER=%s\n' "$name" >> "$GITHUB_ENV"
    trap - EXIT
fi
