#!/usr/bin/env python3
"""Package locally built Wine without any Microsoft files; preserve a runtime layout map."""
import hashlib
import json
from pathlib import Path
import shutil
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
abis = sys.argv[1:]
if not abis or any(abi not in ('x86_64', 'arm64-v8a') for abi in abis):
    sys.exit('Usage: package-wine.py x86_64 [arm64-v8a]')
assets = root / '.build/wine-assets'
assets.mkdir(parents=True, exist_ok=True)
for abi in abis:
    stage = root / f'.build/wine-install-{abi}/opt/officedroid'
    if not (stage / abi / 'bin/wineserver').is_file():
        sys.exit(f'Build Wine for {abi} before packaging')
    native = root / '.build/wine-jniLibs' / abi
    native.mkdir(parents=True, exist_ok=True)
    mapping = {}
    destinations = {}
    archive = assets / f'runtime-{abi}.zip'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=1) as output:
        files = [(p, p.relative_to(stage).as_posix()) for p in sorted(stage.rglob('*')) if p.is_file()]
        freetype = root / f'.build/deps-{abi}/lib/libfreetype.so'
        files.append((freetype, f'{abi}/lib/libfreetype.so'))
        for path, relative in files:
            with path.open('rb') as source:
                is_elf = source.read(4) == b'\x7fELF'
            if is_elf:
                name = {'wine': 'libwine.so', 'wineserver': 'libwineserver.so', 'ntdll.so': 'libntdll.so'}.get(
                    path.name, 'libod_' + path.name.replace('.', '_') + '.so')
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
