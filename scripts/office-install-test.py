#!/usr/bin/env python3
"""Run official ODT inside the Android app, retaining installer evidence, never binaries."""
from pathlib import Path
import argparse
import json
import hashlib
import re
import shlex
import subprocess
import time
import xml.etree.ElementTree as ET

output = Path('.build/emulator/office-install')
output.mkdir(parents=True, exist_ok=True)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--timeout-seconds', type=int, default=1800)
args = parser.parse_args()
if args.timeout_seconds < 120:
    parser.error('--timeout-seconds must be at least 120')


def adb(*args, **kwargs):
    return subprocess.check_output(['adb', *args], timeout=kwargs.pop('timeout', 30), **kwargs)


def private(*args, **kwargs):
    # Shell v2 preserves the remote exit code; -T keeps binary streams unchanged.
    return adb('shell', '-T', 'run-as', 'org.officedroid', *map(shlex.quote, args), **kwargs)


def diagnose():
    """Capture Windows stacks on failure before the emulator is torn down."""
    (output / 'android-processes.txt').write_bytes(adb('shell', 'ps', '-A', '-T'))
    # The ready marker records the APK native directory used by WineRuntime.
    markers = private('find', 'files', '-maxdepth', '2', '-name', '.ready').decode().splitlines()
    for marker in markers:
        native = private('cat', marker).decode()
        try:
            private('test', '-x', native + '/libwine.so')
        except subprocess.CalledProcessError:
            continue
        runtime = private('readlink', '-f', str(Path(marker).parent)).decode().strip()
        app = private('pwd').decode().strip()
        dlls = runtime + '/x86_64/lib/wine'
        environment = [
            'HOME=' + app + '/files', 'TMPDIR=' + app + '/cache/wine',
            'WINEPREFIX=' + app + '/files/prefix', 'WINESERVER=' + native + '/libwineserver.so',
            'WINELOADER=' + native + '/libwine.so', 'WINEDLLPATH=' + dlls,
            'OFFICEDROID_DLL_DIR=' + dlls, 'OFFICEDROID_DATA_DIR=' + runtime + '/share/wine',
            'LD_LIBRARY_PATH=' + native + ':' + dlls + '/x86_64-unix:' + runtime + '/x86_64/lib',
            'WINEDEBUG=-all', 'WINEDLLOVERRIDES=mscoree,mshtml=',
        ]
        # Run only after installation failed: attaching a debugger interrupts
        # threads and must not influence a successful installation measurement.
        # Android's APK path contains '='. Passing it directly to env makes it
        # another NAME=VALUE assignment, so use a shell with positional arguments.
        command = ['timeout', '15', 'env', *environment, '/system/bin/sh', '-c', 'exec "$@"',
                   'wine-debugger', native + '/libwine.so',
                   r'C:\windows\system32\winedbg.exe', '--command']

        def debug(commands):
            try:
                return private(*command, commands, timeout=25, stderr=subprocess.STDOUT)
            except subprocess.CalledProcessError as error:
                return error.output

        listing = debug('info proc\ninfo threads')
        (output / 'windows-processes.txt').write_bytes(listing)
        # "bt all" crashes while formatting an unrelated Explorer frame before
        # reaching setup. Capture each relevant thread independently instead.
        targets = []
        process = None
        for line in listing.decode(errors='replace').splitlines():
            match = re.fullmatch(r'([0-9a-fA-F]{8}) (\S+)', line)
            if match:
                process = match.groups()
            elif process and process[1].lower() in (
                    'setup.exe', 'officeclicktorun.exe', 'officec2rclient.exe',
                    'vc_redist.x64.exe', 'vc_redist.x86.exe', 'msiexec.exe', 'winedevice.exe'):
                match = re.match(r'\s+([0-9a-fA-F]{8})\s', line)
                if match:
                    targets.append((*process, match[1]))
        targets.sort(key=lambda target: (target[1].lower() == 'winedevice.exe', target[1].lower() == 'setup.exe'))
        if not targets:
            raise RuntimeError('WineDbg listed no installer/device threads')
        with (output / 'windows-stacks.txt').open('wb') as stacks:
            for pid, name, tid in targets:
                stacks.write(f'\n{name} process {pid} thread {tid}\n'.encode())
                stacks.write(debug(f'attach 0x{pid}\nbt 0x{tid}\ndetach'))
                stacks.flush()
        return
    raise RuntimeError('No current APK runtime found for WineDbg')


def screen(name):
    path = output / (name + '.png')
    path.write_bytes(adb('exec-out', 'screencap', '-p'))
    text = subprocess.check_output(['tesseract', str(path), 'stdout'], timeout=30).decode()
    (output / (name + '.txt')).write_text(text)
    return text


result = {'office_version': '16.0.20430.20146', 'visual_cpp_version': '14.44.35211', 'installer_passed': False}
try:
    subprocess.run(['./scripts/prepare-office.sh'], check=True, timeout=180)
    adb('shell', 'am', 'force-stop', 'org.officedroid')
    directory = 'files/prefix/drive_c/office-setup'
    private('mkdir', '-p', directory + '/logs')
    private('rm', '-f', directory + '/exit-code.txt', directory + '/phase.txt',
            directory + '/vcredist-x64-exit.txt', directory + '/vcredist-x86-exit.txt')
    for source in [Path('.build/office/odt/setup.exe'), Path('.build/office/odt/EULA'),
                   Path('.build/office/odt/vc_redist.x64.exe'), Path('.build/office/odt/vc_redist.x86.exe'),
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
    deadline = time.monotonic() + args.timeout_seconds
    checkpoint = 0
    while time.monotonic() < deadline:
        phase = subprocess.run(['adb', 'shell', '-T', 'run-as', 'org.officedroid', 'cat', directory + '/phase.txt'],
                               capture_output=True, timeout=15)
        if phase.returncode == 0:
            name = phase.stdout.decode().strip()
            if name != result.get('phase'):
                result['phase'] = name
                print('Installation phase: ' + name, flush=True)
        completed = subprocess.run(['adb', 'shell', '-T', 'run-as', 'org.officedroid', 'cat', directory + '/exit-code.txt'], capture_output=True, timeout=15)
        exit_code = completed.stdout.strip()
        if completed.returncode == 0 and exit_code:
            result['exit_code'] = int(exit_code)
            assert result['exit_code'] == 0, f"{result.get('phase', 'Installation')} failed with exit code {result['exit_code']}"
            for arch in ('x64', 'x86'):
                code = int(private('cat', directory + '/vcredist-' + arch + '-exit.txt').strip())
                result['visual_cpp_' + arch + '_exit_code'] = code
                assert code in (0, 3010), f'Visual C++ {arch} installer failed: {code}'
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
        raise TimeoutError(f"{result.get('phase', 'Installation')} did not finish within {args.timeout_seconds} seconds")
finally:
    screen('final')
    log = subprocess.run(['adb', 'exec-out', 'run-as', 'org.officedroid', 'cat', 'files/wine-gui.log'], capture_output=True, timeout=20)
    (output / 'wine-gui.log').write_bytes(log.stdout + log.stderr)
    files = private('find', 'files/prefix/drive_c/office-setup/logs', 'cache/wine', 'files/prefix/drive_c/users', '-type', 'f', '-name', '*.log').decode().splitlines()
    for index, filename in enumerate(files):
        (output / f'installer-{index}.log').write_bytes(private('cat', filename))
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    if not result['installer_passed']:
        try:
            diagnose()
        except Exception as error:
            (output / 'diagnostic-error.txt').write_text(str(error) + '\n')
