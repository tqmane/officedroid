#!/usr/bin/env bash
# Run the built Wine APK and test APK on an already booted ARM64 Android device.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/emulator/instrumentation
[[ $(adb shell getprop ro.product.cpu.abi | tr -d '\r') == arm64-v8a ]]
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb shell wm dismiss-keyguard
adb shell wm size 2560x1600
adb shell wm density 240
python3 scripts/emulator-ready.py .build/emulator/boot-test-resolution.xml
adb logcat -v threadtime -b main -b system -b crash > .build/emulator/live-logcat.txt 2>&1 &
logcat_pid=$!
trap 'kill "$logcat_pid" 2>/dev/null || true' EXIT
timeout 180s adb install -r app/build/outputs/apk/debug/app-debug.apk
timeout 60s adb install -r app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
instrumentation_status=0
python3 - <<'PY' || instrumentation_status=$?
import json
from pathlib import Path
import re
import subprocess

output = Path('.build/emulator/instrumentation')
# Require every declared test to complete successfully, including Wine tests.
# Android's am command can exit zero after a test failure or process crash.
expected = set()
for source in Path('app/src/androidTest/java/org/officedroid').glob('*Test.java'):
    for method in re.findall(r'@Test\s+public void (\w+)\(', source.read_text()):
        expected.add(('org.officedroid.' + source.stem, method))
with (output / 'raw.txt').open('wb') as log:
    subprocess.run(['adb', 'shell', 'am', 'instrument', '-w', '-r',
                    'org.officedroid.test/androidx.test.runner.AndroidJUnitRunner'],
                   stdout=log, stderr=subprocess.STDOUT, check=True, timeout=1200)
raw = (output / 'raw.txt').read_text(errors='replace')
print(raw, flush=True)
bundle = {}
results = []
for line in raw.splitlines():
    if line.startswith('INSTRUMENTATION_STATUS: '):
        key, _, value = line.removeprefix('INSTRUMENTATION_STATUS: ').partition('=')
        bundle[key] = value
    elif line.startswith('INSTRUMENTATION_STATUS_CODE: '):
        code = int(line.split(':', 1)[1])
        if code != 1:  # 1 starts a test; 0 succeeds; negative values fail/skip.
            results.append({'class': bundle.get('class'), 'test': bundle.get('test'), 'code': code})
        bundle = {}
(output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
assert expected and len(results) == len(expected), (len(results), len(expected))
assert {(r['class'], r['test']) for r in results} == expected, results
assert all(r['code'] == 0 for r in results), 'Failed or skipped instrumentation test'
assert re.search(r'^INSTRUMENTATION_CODE: -1\s*$', raw, re.MULTILINE), raw
assert f'OK ({len(expected)} tests)' in raw, raw
PY
python3 scripts/launch-test.py --wine
gui_status=0
python3 scripts/wine-gui-test.py || gui_status=$?
((instrumentation_status == 0)) || exit "$instrumentation_status"
((gui_status == 0)) || exit "$gui_status"
python3 scripts/wine-gui-test.py --wow64
