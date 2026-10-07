#!/usr/bin/env python3
"""Package locally built Wine without any Microsoft files; preserve a runtime layout map."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
abis = sys.argv[1:]
if not abis or any(abi not in ('x86_64', 'arm64-v8a') for abi in abis):
    sys.exit('Usage: package-wine.py x86_64 [arm64-v8a]')
(root / '.build').mkdir(exist_ok=True)
# Serialize asset writes with Gradle builds and instrumented tests.
lock = (root / '.build/android-build.lock').open('a')
fcntl.flock(lock, fcntl.LOCK_EX)
assets = root / '.build/wine-assets'
assets.mkdir(parents=True, exist_ok=True)
# Ship upstream notices with the binary APK. CI also uploads full corresponding sources.
tool_dir = Path(os.environ.get('OFFICEDROID_TOOLS', root / '.tools'))
notice_sources = {
    'wine': (tool_dir / 'src/wine', ['LICENSE', 'LICENSE.OLD', 'COPYING.LIB', 'AUTHORS']),
    'freetype': (tool_dir / 'src/freetype', ['LICENSE.TXT', 'docs/FTL.TXT', 'src/bdf/README',
        'src/pcf/README', 'src/gzip/zlib.h', 'src/base/fthash.c', 'src/autofit/ft-hb.c']),
    'gmp': (tool_dir / 'src/gmp-6.3.0', ['COPYING', 'COPYING.LESSERv3', 'COPYINGv2', 'COPYINGv3', 'AUTHORS']),
    'nettle': (tool_dir / 'src/nettle-3.10.2', ['COPYING.LESSERv3', 'COPYINGv2', 'COPYINGv3', 'AUTHORS']),
    'gnutls': (tool_dir / 'src/gnutls-3.8.13', ['COPYING', 'COPYING.LESSERv2', 'README.md', 'AUTHORS']),
    'llvm-mingw': (tool_dir / 'llvm-mingw', ['LICENSE.TXT']),
}
for component, (source, names) in notice_sources.items():
    if component == 'gnutls':
        names += [p.relative_to(source).as_posix() for p in source.rglob('*')
                  if p.is_file() and p.name.startswith(('LICENSE', 'COPYING', 'NOTICE')) and p.relative_to(source).as_posix() not in names]
    if component == 'wine':
        names += [p.relative_to(source).as_posix() for p in (source / 'libs').rglob('*')
                  if p.is_file() and p.name.startswith(('LICENSE', 'COPYING', 'NOTICE'))]
    if component == 'llvm-mingw':
        names += [p.relative_to(source).as_posix() for p in
                  (source / 'x86_64-w64-mingw32/share/mingw32').glob('COPYING*')]
    for name in names:
        destination = assets / 'licenses' / component / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / name, destination)
for abi in abis:
    stage = root / f'.build/wine-install-{abi}/opt/officedroid'
    if not (stage / abi / 'bin/wineserver').is_file():
        sys.exit(f'Build Wine for {abi} before packaging')
    compiler = 'aarch64' if abi == 'arm64-v8a' else 'x86_64'
    probe = root / f'.build/https-probe-{abi}.exe'
    subprocess.run([str(tool_dir / f'llvm-mingw/bin/{compiler}-w64-mingw32-clang'),
                    str(root / 'runtime/win32/https-probe.c'), '-O2', '-lwinhttp', '-o', str(probe)], check=True)
    native = root / '.build/wine-jniLibs' / abi
    native.mkdir(parents=True, exist_ok=True)
    mapping = {}
    destinations = {}
    archive = assets / f'runtime-{abi}.zip'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=1) as output:
        files = [(p, p.relative_to(stage).as_posix()) for p in sorted(stage.rglob('*')) if p.is_file()]
        files.append((probe, 'https-probe.exe'))
        for dependency in sorted((root / f'.build/deps-{abi}/lib').glob('*.so*')):
            if dependency.is_file():
                files.append((dependency, f'{abi}/lib/{dependency.name}'))
        for path, relative in files:
            with path.open('rb') as source:
                header = source.read(64)
                is_elf = header[:4] == b'\x7fELF'
            if is_elf:
                machine = 62 if abi == 'x86_64' else 183
                if len(header) < 64 or header[4:6] != b'\x02\x01' or struct.unpack_from('<H', header, 18)[0] != machine:
                    sys.exit(f'Wrong ELF ABI for {abi}: {relative}')
                name = {'wine': 'libwine.so', 'wineserver': 'libwineserver.so', 'ntdll.so': 'libntdll.so'}.get(
                    path.name, 'libod_' + path.resolve().name.replace('.', '_') + '.so')
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
                if name in destinations and destinations[name] != digest:
                    sys.exit(f'Conflicting native library name: {name}')
                destinations[name] = digest
                shutil.copyfile(path, native / name)
                mapping[relative] = name
            else:
                output.write(path, relative)
    metadata = {
        'wine': '11.0', 'abi': abi, 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
        'native': mapping,
    }
    (assets / f'layout-{abi}.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(f'{abi}: {archive.stat().st_size} bytes of PE/data; {len(destinations)} APK-installed native binaries')
