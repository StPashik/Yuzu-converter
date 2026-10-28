#!/usr/bin/env python3
"""Reuse only a complete, verified media build for this architecture and toolchain."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

CONFIGURATIONS = (
    'build-ffmpeg/config.h', 'build-ffmpeg/config_components.h',
    'build-ffmpeg/ffbuild/config.mak', 'build-ffmpeg/ffbuild/config.log',
    'build-lame/config.h', 'build-opus/config.h', 'build-libvpx/vpx_config.h',
)
FILES = ('Tools/ffmpeg', 'Tools/ffprobe', *(f'configurations/{name}' for name in CONFIGURATIONS))


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def toolchain():
    def output(*args):
        return subprocess.check_output(args, text=True).strip()
    return {
        'sdk': output('xcrun', '--sdk', 'macosx', '--show-sdk-version'),
        'sdkBuild': output('xcrun', '--sdk', 'macosx', '--show-sdk-build-version'),
        'clang': output('xcrun', 'clang', '--version'),
    }


def identity(root, arch):
    return {
        'schema': 1, 'arch': arch, 'minimumOS': '13.0', 'toolchain': toolchain(),
        'inputs': {name: sha256(root / name) for name in (
            'Resources/Media-sources.json', 'scripts/build-media.py', 'scripts/media_cache.py')},
    }


def key(root, arch):
    digest = hashlib.sha256(json.dumps(identity(root, arch), sort_keys=True).encode()).hexdigest()
    return f'yuzu-media-v1-{arch}-{digest}'


def verify_tools(output, arch):
    cpu = 'arm64' if arch == 'arm64' else 'x86_64'
    for name in ('ffmpeg', 'ffprobe'):
        executable = output / 'Tools' / name
        if not os.access(executable, os.X_OK):
            raise ValueError(f'Non-executable media tool: {name}')
        actual = subprocess.check_output(['lipo', '-archs', executable], text=True).strip()
        if actual != cpu:
            raise ValueError(f'Incorrect architecture: {name}: {actual}')
        libraries = subprocess.check_output(['otool', '-L', executable], text=True).splitlines()[1:]
        if any(not line.strip().startswith(('/usr/lib/', '/System/Library/')) for line in libraries):
            raise ValueError(f'Non-system runtime dependency: {name}')


def source_archives(root):
    for name, source in json.loads((root / 'Resources/Media-sources.json').read_text()).items():
        suffix = '.tar.xz' if name == 'ffmpeg' else '.tar.gz'
        yield root / f".build/media-sources/{name}-{source['version']}{suffix}", source['sha256']


def verify(root, arch):
    output = root / f'.build/media-{arch}'
    try:
        receipt = json.loads((output / 'receipt.json').read_text())
        if receipt['identity'] != identity(root, arch) or set(receipt['files']) != set(FILES):
            return False
        if any((output / name).is_symlink() or not (output / name).is_file() or
               sha256(output / name) != receipt['files'][name] for name in FILES):
            return False
        if any(path.is_symlink() or sha256(path) != expected for path, expected in source_archives(root)):
            return False
        verify_tools(output, arch)
        return True
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        return False


def record(root, arch, work):
    output = root / f'.build/media-{arch}'
    for name in CONFIGURATIONS:
        target = output / 'configurations' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(work / name, target)
    verify_tools(output, arch)
    receipt = {'identity': identity(root, arch), 'files': {name: sha256(output / name) for name in FILES}}
    # Configurations travel with the tools; cache hits never depend on a previous runner's /tmp path.
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['key', 'verify'])
    parser.add_argument('arch', choices=['arm64', 'x64'])
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    if args.command == 'key':
        print(key(root, args.arch))
    elif not verify(root, args.arch):
        raise SystemExit('Media cache is missing, stale, or incomplete.')
    else:
        print(f'Verified media cache: {args.arch}')


if __name__ == '__main__':
    main()
