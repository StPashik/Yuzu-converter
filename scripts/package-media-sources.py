#!/usr/bin/env python3
"""Package corresponding source and the actual build configuration beside release binaries."""

import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

root = Path(__file__).resolve().parent.parent
version = json.loads((root / "package.json").read_text())["version"]
sources = json.loads((root / "Resources/Media-sources.json").read_text())
destination = root / "dist" / f"Yuzu-FFmpeg-Sources-{version}.tar.xz"
destination.parent.mkdir(exist_ok=True)
with tarfile.open(destination, "w:xz") as archive:
    for relative in ["Resources/Media-sources.json", "scripts/build-media.py", "docs/Bundled-media.md"]:
        archive.add(root / relative, arcname=relative)
    for name, source in sources.items():
        suffix = ".tar.xz" if name == "ffmpeg" else ".tar.gz"
        relative = f".build/media-sources/{name}-{source['version']}{suffix}"
        path = root / relative
        if hashlib.sha256(path.read_bytes()).hexdigest() != source["sha256"]:
            raise SystemExit(f"Incorrect source archive: {path}")
        archive.add(path, arcname=relative)
    for arch in ["arm64", "x64"]:
        work = Path((root / f".build/media-{arch}/build-path.txt").read_text().strip())
        for relative in ["build-ffmpeg/config.h", "build-ffmpeg/config_components.h",
                         "build-ffmpeg/ffbuild/config.mak", "build-ffmpeg/ffbuild/config.log",
                         "build-lame/config.h", "build-opus/config.h", "build-libvpx/vpx_config.h"]:
            archive.add(work / relative, arcname=f"build-configurations/{arch}/{relative}")
        info = root / f".build/media-{arch}/binary-info.txt"
        lines = []
        for tool in ["ffmpeg", "ffprobe"]:
            path = root / f".build/media-{arch}/Tools/{tool}"
            lines.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {tool}\n")
            lines.append(subprocess.check_output([path, "-version"], stderr=subprocess.STDOUT, text=True))
        info.write_text("\n".join(lines))
        archive.add(info, arcname=f"build-configurations/{arch}/binary-info.txt")
print(f"Packaged corresponding source: {destination}")
