#!/usr/bin/env python3
"""Keep SDK Manager on the same verified HTTPS proxy route as curl."""
import os
from pathlib import Path
import sys
from urllib.parse import urlsplit

command = [str(Path(os.environ['ANDROID_HOME']) / 'cmdline-tools/19.0/bin/sdkmanager')]
proxy_url = os.environ.get('HTTPS_PROXY') or os.environ.get('https_proxy')
if proxy_url:
    proxy = urlsplit(proxy_url)
    if proxy.scheme != 'http' or not proxy.hostname or proxy.username or proxy.password:
        sys.exit('SDK Manager requires an unauthenticated HTTP CONNECT proxy; use the platform route')
    command += ['--proxy=http', '--proxy_host=' + proxy.hostname, '--proxy_port=' + str(proxy.port or 80)]
os.execv(command[0], command + sys.argv[1:])
