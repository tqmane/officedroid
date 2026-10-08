#!/usr/bin/env python3
"""Run official ODT inside the Android app, retaining installer evidence, never binaries."""
from pathlib import Path
import json
import hashlib
import re
import shlex
import subprocess
import time
import xml.etree.ElementTree as ET

output = Path('.build/emulator/office-install')
output.mkdir(parents=True, exist_ok=True)


def adb(*args, **kwargs):
    return subprocess.check_output(['adb', *args], timeout=30, **kwargs)


def private(*args):
    # Shell v2 preserves the remote exit code; -T keeps binary streams unchanged.
    return adb('shell', '-T', 'run-as', 'org.officedroid', *map(shlex.quote, args))


def screen(name):
    path = output / (name + '.png')
    path.write_bytes(adb('exec-out', 'screencap', '-p'))
    text = subprocess.check_output(['tesseract', str(path), 'stdout'], timeout=30).decode()
    (output / (name + '.txt')).write_text(text)
    return text


result = {'office_version': '16.0.20430.20146', 'installer_passed': False}
try:
    subprocess.run(['./scripts/prepare-office.sh'], check=True, timeout=180)
    adb('shell', 'am', 'force-stop', 'org.officedroid')
    directory = 'files/prefix/drive_c/office-setup'
    private('mkdir', '-p', directory + '/logs')
    private('rm', '-f', directory + '/exit-code.txt')
    for source in [Path('.build/office/odt/setup.exe'), Path('.build/office/odt/EULA'),
                   Path('runtime/office/configuration.xml'), Path('runtime/office/install-office.cmd')]:
        command = 'cat > ' + shlex.quote(directory + '/' + source.name)
        # exec-in quotes these arguments again and does not wait for remote exit.
        adb('shell', '-T', 'run-as', 'org.officedroid', 'sh', '-c', shlex.quote(command), input=source.read_bytes())
        actual = private('sha256sum', directory + '/' + source.name).decode().split()[0]
        expected = hashlib.sha256(source.read_bytes()).hexdigest()
        assert actual == expected, f'{source.name}: staged SHA-256 {actual}, expected {expected}'
        print(f'Staged and verified {source.name}: {source.stat().st_size} bytes', flush=True)
    adb('shell', 'am', 'start', '-W', '-n', 'org.officedroid/.MainActivity')
    adb('shell', 'uiautomator', 'dump', '/sdcard/office-install.xml')
    nodes = ET.fromstring(adb('exec-out', 'cat', '/sdcard/office-install.xml')).iter('node')
    button = next(n for n in nodes if n.get('text', '').casefold() == 'install microsoft 365')
    left, top, right, bottom = map(int, re.findall(r'\d+', button.get('bounds')))
    adb('shell', 'input', 'tap', str((left + right) // 2), str((top + bottom) // 2))
    deadline = time.monotonic() + 1800
    checkpoint = 0
    while time.monotonic() < deadline:
        completed = subprocess.run(['adb', 'shell', '-T', 'run-as', 'org.officedroid', 'cat', directory + '/exit-code.txt'], capture_output=True, timeout=15)
        if completed.returncode == 0:
            result['exit_code'] = int(completed.stdout.strip())
            assert result['exit_code'] == 0, f"ODT failed with exit code {result['exit_code']}"
            for exe in ['WINWORD.EXE', 'EXCEL.EXE', 'POWERPNT.EXE']:
                private('test', '-s', 'files/prefix/drive_c/Program Files/Microsoft Office/root/Office16/' + exe)
            result['installer_passed'] = True
            print('PASS: ODT exited successfully and installed the three application executables', flush=True)
            break
        if time.monotonic() >= checkpoint:
            text = screen('progress-' + str(int(time.monotonic())))
            print('Office installer screenshot and OCR captured', flush=True)
            if re.search(r"couldn't install|can't install|error code|not supported", text, re.I):
                raise RuntimeError('Office reported an installation error; see captured screen and logs')
            checkpoint = time.monotonic() + 60
        time.sleep(5)
    else:
        raise TimeoutError('ODT did not finish within 30 minutes')
finally:
    screen('final')
    log = subprocess.run(['adb', 'exec-out', 'run-as', 'org.officedroid', 'cat', 'files/wine-gui.log'], capture_output=True, timeout=20)
    (output / 'wine-gui.log').write_bytes(log.stdout + log.stderr)
    files = private('find', 'files/prefix/drive_c/office-setup/logs', 'cache/wine', 'files/prefix/drive_c/users', '-type', 'f', '-name', '*.log').decode().splitlines()
    for index, filename in enumerate(files):
        (output / f'installer-{index}.log').write_bytes(private('cat', filename))
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
