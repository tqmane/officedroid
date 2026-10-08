#!/usr/bin/env python3
"""Measure ARM64 Android software boot on a standard Actions runner."""
import json
import argparse
import os
import platform
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--keep-running', action='store_true', help='Caller must stop the recorded emulator PID')
parser.add_argument('--timeout-seconds', type=int, default=900)
args = parser.parse_args()
if args.timeout_seconds < 1:
    parser.error('--timeout-seconds must be positive')
root = Path(__file__).resolve().parent.parent
sdk = root / '.tools/android-arm64-sdk'
output = root / '.build/arm64-boot'
output.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk),
           ANDROID_USER_HOME=str(root / '.tools/android-arm64-user'),
           ANDROID_AVD_HOME=str(root / '.tools/android-arm64-user/avd'))
adb = str(sdk / 'platform-tools/adb')
result = {'boot_completed': False, 'acceleration': 'off', 'expected_abi': 'arm64-v8a',
          'qemu_cpu': 'max', 'vcpus': 1, 'tcg_threads': 'single'}
start = time.monotonic()
emulator = sdk / 'emulator/emulator'
qemu = ['-accel', 'tcg,thread=single', '-cpu', 'max']
if platform.system() == 'Linux':
    # The SDK frontend rejects ARM64 guests on x86 hosts before invoking QEMU.
    # Exercise its bundled AArch64 engine directly; the Android guest stays ARM64.
    emulator = sdk / 'emulator/qemu/linux-x86_64/qemu-system-aarch64-headless'
    env['ANDROID_EMULATOR_LAUNCHER_DIR'] = str(sdk / 'emulator')
    env['LD_LIBRARY_PATH'] = ':'.join(str(p) for p in
        [sdk / 'emulator/lib64', sdk / 'emulator/lib64/gles_swiftshader',
         sdk / 'emulator/lib64/qt/lib'])
    qemu += ['-machine', 'type=virt']
with (output / 'emulator.log').open('w') as log:
    process = subprocess.Popen([
        str(emulator), '-avd', 'officedroid-arm64',
        '-accel', 'off', '-no-window', '-no-audio', '-no-snapshot', '-wipe-data',
        '-no-boot-anim', '-show-kernel', '-gpu', 'swiftshader', '-cores', '1',
        '-memory', '3072', '-camera-back', 'none', '-camera-front', 'none',
        # The ARM64 macOS frontend still adds -enable-hvf with -accel off.
        # Explicitly request the QEMU software accelerator after frontend options.
        '-port', '5554', '-verbose', '-qemu', *qemu],
        env=env, stdout=log, stderr=subprocess.STDOUT)
    result['emulator_pid'] = process.pid
    try:
        while time.monotonic() - start < args.timeout_seconds:
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
            raise TimeoutError(f'ARM64 Android did not complete boot within {args.timeout_seconds} seconds')
    except Exception as error:
        result['error'] = str(error)
        raise
    finally:
        result['elapsed_seconds'] = round(time.monotonic() - start, 1)
        (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        for name, arguments in [('devices', ['devices', '-l']),
                                ('properties', ['-s', 'emulator-5554', 'shell', 'getprop']),
                                ('logcat', ['-s', 'emulator-5554', 'logcat', '-b', 'all', '-d'])]:
            with (output / (name + '.txt')).open('w') as diagnostic:
                try:
                    subprocess.run([adb, *arguments], env=env, stdout=diagnostic,
                                   stderr=subprocess.STDOUT, timeout=20)
                except subprocess.TimeoutExpired:
                    diagnostic.write('\nDiagnostic timed out after 20 seconds.\n')
        if not (args.keep_running and result['boot_completed']):
            process.terminate()
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
print(json.dumps(result))
