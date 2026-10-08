#!/usr/bin/env python3
"""Measure ARM64 Android software boot on a standard ARM64 macOS runner."""
import json
import os
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parent.parent
sdk = root / '.tools/android-arm64-sdk'
output = root / '.build/arm64-boot'
output.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk),
           ANDROID_USER_HOME=str(root / '.tools/android-arm64-user'),
           ANDROID_AVD_HOME=str(root / '.tools/android-arm64-user/avd'))
adb = str(sdk / 'platform-tools/adb')
result = {'boot_completed': False, 'acceleration': 'off', 'expected_abi': 'arm64-v8a'}
start = time.monotonic()
with (output / 'emulator.log').open('w') as log:
    process = subprocess.Popen([
        str(sdk / 'emulator/emulator'), '-avd', 'officedroid-arm64',
        '-accel', 'off', '-no-window', '-no-audio', '-no-snapshot',
        '-no-boot-anim', '-gpu', 'swiftshader', '-cores', '2',
        '-memory', '3072', '-camera-back', 'none', '-camera-front', 'none',
        '-port', '5554', '-verbose'], env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        while time.monotonic() - start < 900:
            if process.poll() is not None:
                raise RuntimeError(f'Emulator exited {process.returncode}; see emulator.log')
            try:
                boot = subprocess.run([adb, '-s', 'emulator-5554', 'shell', 'getprop',
                                       'sys.boot_completed'], capture_output=True, text=True,
                                      timeout=15, env=env)
                if boot.returncode == 0 and boot.stdout.strip() == '1':
                    abi = subprocess.check_output([adb, '-s', 'emulator-5554', 'shell',
                                                   'getprop', 'ro.product.cpu.abi'],
                                                  timeout=15, env=env, text=True).strip()
                    result['actual_abi'] = abi
                    if abi != 'arm64-v8a':
                        raise RuntimeError(f'Wrong Android ABI: {abi}')
                    with (output / 'boot.png').open('wb') as screen:
                        subprocess.run([adb, '-s', 'emulator-5554', 'exec-out', 'screencap', '-p'],
                                       stdout=screen, timeout=30, env=env, check=True)
                    result['boot_completed'] = True
                    break
            except subprocess.TimeoutExpired:
                pass
            time.sleep(5)
        if not result['boot_completed']:
            raise TimeoutError('ARM64 Android did not complete boot within 900 seconds')
    except Exception as error:
        result['error'] = str(error)
        raise
    finally:
        result['elapsed_seconds'] = round(time.monotonic() - start, 1)
        (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        process.terminate()
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
print(json.dumps(result))
