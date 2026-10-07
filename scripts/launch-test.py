#!/usr/bin/env python3
"""Verify launcher UI and native startup on an already booted Android device."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

output = Path('.build/emulator/launch')
output.mkdir(parents=True, exist_ok=True)
with_wine = '--wine' in sys.argv[1:]


def adb(*args):
    return subprocess.check_output(['adb', *args], timeout=30)


def screen(activity, expected):
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        adb('shell', 'uiautomator', 'dump', '/sdcard/officedroid-ui.xml')
        xml = adb('exec-out', 'cat', '/sdcard/officedroid-ui.xml')
        (output / f'{activity}.xml').write_bytes(xml)
        nodes = list(ET.fromstring(xml).iter('node'))
        texts = [n.get('text', '') for n in nodes if n.get('package') == 'org.officedroid']
        if expected[0] in texts and all(any(value in text for text in texts) for value in expected[1:]):
            return nodes
        time.sleep(1)
    raise RuntimeError(f'{activity}: expected visible text {expected}; see saved UI XML')


results = []
for activity, title in [('MainActivity', 'OfficeDroid'), ('WordActivity', 'Word · OfficeDroid'),
                        ('ExcelActivity', 'Excel · OfficeDroid'), ('PowerPointActivity', 'PowerPoint · OfficeDroid')]:
    # Each entry must survive a fresh application process, as a launcher tap does.
    adb('shell', 'am', 'force-stop', 'org.officedroid')
    launch = adb('shell', 'am', 'start', '-W', '-a', 'android.intent.action.MAIN',
                 '-c', 'android.intent.category.LAUNCHER', '-n', f'org.officedroid/.{activity}')
    (output / f'{activity}.txt').write_bytes(launch)
    if b'Status: ok' not in launch:
        raise RuntimeError(launch.decode())
    try:
        nodes = screen(activity, [title, '"ok":true'])
        if with_wine and activity == 'MainActivity':
            button = next(n for n in nodes if n.get('text', '').casefold() == 'check wine version')
            x1, y1, x2, y2 = map(int, re.findall(r'\d+', button.get('bounds')))
            adb('shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2))
            screen(activity, [title, 'wine-11.0'])
        resumed = adb('shell', 'dumpsys', 'activity', 'activities').decode()
        (output / f'{activity}-activities.txt').write_text(resumed)
        if not any(('topResumedActivity=' in line or 'mResumedActivity:' in line)
                   and f'org.officedroid/.{activity}' in line
                   for line in resumed.splitlines()):
            raise RuntimeError(f'{activity} is not resumed')
        results.append({'activity': activity, 'visible': True, 'native_probe': True,
                        'wine_version_from_button': with_wine and activity == 'MainActivity'})
        print(f'PASS: Android diagnostic launcher {activity} displayed its native probe result', flush=True)
    finally:
        (output / f'{activity}.png').write_bytes(adb('exec-out', 'screencap', '-p'))

(output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
if os.environ.get('GITHUB_STEP_SUMMARY'):
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as summary:
        summary.write('### Android launcher verification\n\n')
        summary.write('All four launcher screens displayed a successful native diagnostic.\n\n')
        if with_wine:
            summary.write('The main screen’s **Check Wine version** button displayed `wine-11.0`.\n\n')
        summary.write('Screenshots, UI XML and launch logs: `.build/emulator/launch/` in the results artifact.\n\n')
        summary.write('Word, Excel and PowerPoint screens are diagnostic launchers; Microsoft Office is not installed.\n')
