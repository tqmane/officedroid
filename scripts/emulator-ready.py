#!/usr/bin/env python3
"""Require a stable Android home screen before installing the test application."""
from pathlib import Path
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

output = Path(sys.argv[1])
deadline = time.monotonic() + 90
stable_since = None
while time.monotonic() < deadline:
    try:
        subprocess.run(['adb', 'shell', 'rm', '-f', '/sdcard/boot-ui.xml'], check=True, timeout=15)
        subprocess.run(['adb', 'shell', 'uiautomator', 'dump', '/sdcard/boot-ui.xml'],
                       check=True, timeout=15, stdout=subprocess.DEVNULL)
        xml = subprocess.check_output(['adb', 'exec-out', 'cat', '/sdcard/boot-ui.xml'], timeout=15)
        output.write_bytes(xml)
        nodes = list(ET.fromstring(xml).iter('node'))
        if any(n.get('resource-id', '').startswith('android:id/aerr_') for n in nodes):
            raise SystemExit('Android failed during boot, before the application was installed')
        if any(n.get('package') == 'com.android.launcher3' for n in nodes):
            if stable_since is None:
                stable_since = time.monotonic()
            if time.monotonic() - stable_since >= 10:
                print('Android home screen is stable; application tests may start', flush=True)
                break
        else:
            stable_since = None
    except (subprocess.SubprocessError, ET.ParseError):
        stable_since = None
    time.sleep(2)
else:
    raise SystemExit('Android home screen did not become ready before application installation')
