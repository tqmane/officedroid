#!/usr/bin/env python3
"""Inventory ARM64 VM acceleration; this is not an Android execution test."""
import json
import os
from pathlib import Path
import platform
import subprocess
import tempfile

result = {'system': platform.system(), 'machine': platform.machine(),
          'acceleration_available': False, 'android_tested': False}
if result['machine'] not in ('aarch64', 'arm64'):
    raise SystemExit('This job requires a native ARM64 host')
try:
    if result['system'] == 'Linux':
        import fcntl
        with open('/dev/kvm', 'r+b', buffering=0) as kvm:
            result['kvm_api_version'] = fcntl.ioctl(kvm, 0xAE00, 0)
            vm = fcntl.ioctl(kvm, 0xAE01, 0)
            os.close(vm)
            result['acceleration_available'] = result['kvm_api_version'] == 12
    elif result['system'] == 'Darwin':
        with tempfile.TemporaryDirectory() as name:
            tmp = Path(name)
            source = tmp / 'hv.c'
            source.write_text('#include <Hypervisor/hv.h>\n#include <stdio.h>\n'
                              'int main(void) { hv_return_t r = hv_vm_create(NULL); '
                              'printf("0x%08x\\n", (unsigned)r); '
                              'if (!r) hv_vm_destroy(); return r ? 1 : 0; }\n')
            entitlement = tmp / 'entitlements.plist'
            entitlement.write_text('<?xml version="1.0"?><plist version="1.0"><dict>'
                                   '<key>com.apple.security.hypervisor</key><true/></dict></plist>')
            executable = tmp / 'hv'
            subprocess.run(['clang', str(source), '-framework', 'Hypervisor', '-o', str(executable)], check=True)
            subprocess.run(['codesign', '-s', '-', '--entitlements', str(entitlement), str(executable)], check=True)
            probe = subprocess.run([str(executable)], capture_output=True, text=True, timeout=15)
            result['hypervisor_result'] = probe.stdout.strip()
            result['hypervisor_stderr'] = probe.stderr.strip()
            result['acceleration_available'] = probe.returncode == 0
except (OSError, subprocess.SubprocessError) as error:
    result['error'] = f'{type(error).__name__}: {error}'
output = Path('.build/arm64-host')
output.mkdir(parents=True, exist_ok=True)
(output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
