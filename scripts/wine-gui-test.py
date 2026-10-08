#!/usr/bin/env python3
"""Exercise actual Win32 Notepad input and saving through the Android surface."""
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

output = Path('.build/emulator/gui')
output.mkdir(parents=True, exist_ok=True)


def adb(*args):
    for attempt in range(3):
        try:
            return subprocess.check_output(['adb', *args], timeout=30, stderr=subprocess.PIPE)
        except subprocess.CalledProcessError as error:
            # Recover read-only captures after a transient emulator disconnect.
            # Input events must never be replayed: that could duplicate an edit.
            if args[0] != 'exec-out' or b'device offline' not in error.stderr or attempt == 2:
                raise
            print('Waiting for the emulator to reconnect before reading evidence', flush=True)
            subprocess.run(['adb', 'wait-for-device'], check=True, timeout=30)


def hierarchy():
    adb('shell', 'uiautomator', 'dump', '/sdcard/officedroid-gui.xml')
    xml = adb('exec-out', 'cat', '/sdcard/officedroid-gui.xml')
    (output / 'screen.xml').write_bytes(xml)
    return list(ET.fromstring(xml).iter('node'))


def open_editor():
    adb('shell', 'am', 'force-stop', 'org.officedroid')
    adb('shell', 'am', 'start', '-W', '-n', 'org.officedroid/.MainActivity')
    nodes = hierarchy()
    button = next(n for n in nodes if n.get('text', '').casefold() == 'open windows editor')
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', button.get('bounds')))
    adb('shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2))
    deadline = time.monotonic() + 180
    window = None
    while time.monotonic() < deadline:
        nodes = hierarchy()
        for node in nodes:
            if node.get('text', '').startswith('Wine GUI startup failed:'):
                raise RuntimeError(node.get('text'))
        windows = []
        for node in nodes:
            if not node.get('content-desc', '').startswith('Wine window '):
                continue
            bounds = list(map(int, re.findall(r'\d+', node.get('bounds'))))
            left, top, right, bottom = bounds
            if right - left >= 300 and bottom - top >= 200:
                windows.append(bounds)
        # The desktop and an application window must both exist.
        if len(windows) >= 2:
            window = min(windows, key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))
            break
        time.sleep(2)
    if window is None:
        raise RuntimeError('No Win32 application surface appeared; inspect wine-gui.log and screenshot')
    return window


def capture(name):
    try:
        log = adb('exec-out', 'run-as', 'org.officedroid', 'tail', '-c', '65536', 'files/wine-gui.log')
        if log:
            (output / (name + '-wine.log')).write_bytes(log)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        (output / (name + '-log-error.txt')).write_text(str(error))
    screenshot = output / (name + '.png')
    screenshot.write_bytes(adb('exec-out', 'screencap', '-p'))
    text = subprocess.check_output(['tesseract', str(screenshot), 'stdout'], timeout=30).decode()
    (output / (name + '-ocr.txt')).write_text(text)
    return re.sub(r'[^A-Z0-9]', '', text.upper())


try:
    # A previous successful run must never satisfy a later failed input test.
    adb('shell', 'am', 'force-stop', 'org.officedroid')
    adb('shell', 'run-as', 'org.officedroid', 'rm', '-f', 'files/prefix/drive_c/gui-smoke.txt')
    window = open_editor()
    deadline = time.monotonic() + 30
    while 'NOTEPAD' not in capture('opened'):
        assert time.monotonic() < deadline, 'Win32 window must paint its title before keyboard tests'
        time.sleep(2)
    adb('shell', 'input', 'tap', str(window[0] + 120), str(window[1] + 120))
    adb('shell', 'input', 'keycombination', '113', '29')  # Ctrl+A
    adb('shell', 'input', 'text', 'OFFICEDROIDGUI')
    time.sleep(1)
    assert 'OFFICEDROIDGUI' in capture('typed'), 'Keyboard input must visibly appear in the document'
    adb('shell', 'input', 'keycombination', '113', '29')  # Select text
    adb('shell', 'input', 'keycombination', '113', '31')  # Ctrl+C
    adb('shell', 'input', 'keyevent', '123')  # End
    adb('shell', 'input', 'keyevent', '66')  # Enter
    adb('shell', 'input', 'keycombination', '113', '50')  # Ctrl+V
    time.sleep(1)
    assert capture('pasted').count('OFFICEDROIDGUI') >= 2, 'Copy/paste must visibly duplicate the text'
    adb('shell', 'input', 'keycombination', '113', '54')  # Ctrl+Z
    adb('shell', 'input', 'keycombination', '113', '47')  # Ctrl+S
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        document = adb('exec-out', 'run-as', 'org.officedroid', 'cat', 'files/prefix/drive_c/gui-smoke.txt')
        (output / 'gui-smoke.txt').write_bytes(document)
        encoding = 'utf-16' if document.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig'
        if document.decode(encoding).strip() == 'OFFICEDROIDGUI':
            break
        time.sleep(1)
    else:
        raise RuntimeError('Android keyboard input and Ctrl+S did not persist the document')
    assert 'OFFICEDROIDGUI' in capture('edited'), 'Saved input must also be visibly rendered'
    open_editor()
    time.sleep(2)
    assert 'OFFICEDROIDGUI' in capture('reopened'), 'Reopened document must visibly contain the saved input'
    print('PASS: Win32 editor displayed Android input, saved it, and reopened the document', flush=True)
finally:
    for name, command in [('wine-gui.log', ['run-as', 'org.officedroid', 'tail', '-c', '65536', 'files/wine-gui.log']),
                          ('screen.png', ['screencap', '-p'])]:
        try:
            data = adb('exec-out', *command)
            (output / name).write_bytes(data)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            print(f'Could not collect {name}: {error}', flush=True)
