#!/usr/bin/env python3
"""Verify real Office editing, OOXML persistence and cold reopening on Android."""
import csv
import io
import json
from pathlib import Path
import re
import shlex
import subprocess
import time
import xml.etree.ElementTree as ET
import zipfile

output = Path('.build/emulator/office-edit')
output.mkdir(parents=True, exist_ok=True)
results = []


def adb(*args, **kwargs):
    return subprocess.check_output(['adb', *args], timeout=30, **kwargs)


def normalized(text):
    return re.sub(r'[^A-Z0-9]', '', text.upper())


def screen(path):
    image = path.with_suffix('.png')
    image.write_bytes(adb('exec-out', 'screencap', '-p'))
    tsv = subprocess.check_output(['tesseract', str(image), 'stdout', 'tsv'], timeout=30).decode()
    path.with_suffix('.tsv').write_text(tsv)
    return list(csv.DictReader(io.StringIO(tsv), delimiter='\t'))


def visible_token(path, token):
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        words = screen(path)
        for word in words:
            if normalized(word['text']) == token:
                return (int(word['left']) + int(word['width']) // 2,
                        int(word['top']) + int(word['height']) // 2)
        time.sleep(3)
    raise AssertionError(f'{token} was not visible in the Office document; inspect screenshot')


def launch(activity, filename):
    adb('shell', 'am', 'force-stop', 'org.officedroid')
    adb('shell', 'am', 'start', '-W', '-n', 'org.officedroid/.' + activity,
        '--es', 'test_document', filename)


for app, extension, initial in [('Word', 'docx', 'INITIALWORD'),
                                ('Excel', 'xlsx', 'INITIALEXCEL'),
                                ('PowerPoint', 'pptx', 'INITIALPPT')]:
    directory = output / app.lower()
    directory.mkdir(exist_ok=True)
    result = {'application': app, 'passed': False}
    results.append(result)
    try:
        filename = f'office-edit-{app.lower()}.{extension}'
        destination = 'files/prefix/drive_c/' + filename
        source = Path('tests/fixtures') / filename
        # Overwrite only this test's own fixture before each edit attempt.
        command = 'cat > ' + shlex.quote(destination)
        adb('exec-in', 'run-as', 'org.officedroid', 'sh', '-c', shlex.quote(command), input=source.read_bytes())
        launch(app + 'Activity', filename)
        x, y = visible_token(directory / 'opened', initial)
        adb('shell', 'input', 'tap', str(x), str(y))
        if app == 'Excel':
            adb('shell', 'input', 'keycombination', '113', '122')  # Ctrl+Home
        else:
            if app == 'PowerPoint':
                adb('shell', 'input', 'keyevent', '132')  # F2: edit selected shape text
            adb('shell', 'input', 'keycombination', '113', '29')  # Ctrl+A
        marker = 'OFFICEDROID' + app.upper()
        adb('shell', 'input', 'text', marker)
        if app == 'Excel':
            adb('shell', 'input', 'keyevent', '66')  # Commit cell edit
        adb('shell', 'input', 'keycombination', '113', '47')  # Ctrl+S
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            data = adb('exec-out', 'run-as', 'org.officedroid', 'cat', destination)
            try:
                with zipfile.ZipFile(io.BytesIO(data)) as package:
                    text = ''.join(''.join(ET.fromstring(package.read(name)).itertext())
                        for name in package.namelist()
                        if name.endswith('.xml') and name.startswith(('word/', 'xl/', 'ppt/slides/')))
                if marker in text and initial not in text:
                    (directory / filename).write_bytes(data)
                    result['saved_content_verified'] = True
                    break
            except zipfile.BadZipFile:
                pass  # Ctrl+S can still be replacing the package.
            time.sleep(2)
        else:
            raise AssertionError(f'{app} did not save the edited OOXML content')
        visible_token(directory / 'edited', marker)
        launch(app + 'Activity', filename)
        visible_token(directory / 'reopened', marker)
        result['passed'] = True
        print(f'PASS: {app} displayed, edited, saved and reopened the document', flush=True)
    finally:
        screen(directory / 'final')
        log = subprocess.run(['adb', 'exec-out', 'run-as', 'org.officedroid', 'cat', 'files/wine-gui.log'],
                             capture_output=True, timeout=20)
        (directory / 'wine-gui.log').write_bytes(log.stdout + log.stderr)
        (output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
