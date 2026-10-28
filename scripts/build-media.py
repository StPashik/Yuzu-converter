#!/usr/bin/env python3
"""Build pinned, standalone LGPL media executables; never use a Homebrew codec library."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

import media_cache


def run(arguments, directory, environment):
    print("Running:", " ".join(map(str, arguments)), flush=True)
    subprocess.run(list(map(str, arguments)), cwd=directory, env=environment, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("arch", choices=["arm64", "x64"])
    parser.add_argument("--reuse", action="store_true", help="Verify and reuse an exact local or CI cache hit.")
    arguments = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    if arguments.reuse and media_cache.verify(root, arguments.arch):
        print(f"Verified media cache hit: {arguments.arch}", flush=True)
        return
    print(f"Building media cache miss: {arguments.arch}", flush=True)
    sources = json.loads((root / "Resources/Media-sources.json").read_text())
    downloads = root / ".build/media-sources"
    # Upstream makefiles do not support spaces in their build/prefix paths.
    work = Path(tempfile.mkdtemp(prefix=f"yuzu-media-{arguments.arch}-"))
    output = root / f".build/media-{arguments.arch}"
    prefix = work / "install"
    downloads.mkdir(parents=True, exist_ok=True)
    work.mkdir(parents=True, exist_ok=True)
    prefix.mkdir(exist_ok=True)
    arch = "arm64" if arguments.arch == "arm64" else "x86_64"
    host = "aarch64" if arch == "arm64" else arch
    sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
    flags = f"-arch {arch} -mmacosx-version-min=13.0 -isysroot {sdk} -O2"
    environment = dict(os.environ, CC="clang", CXX="clang++", CFLAGS=flags, CXXFLAGS=flags,
                       LDFLAGS=flags, MACOSX_DEPLOYMENT_TARGET="13.0",
                       PKG_CONFIG_PATH="", PKG_CONFIG_LIBDIR=str(prefix / "lib/pkgconfig"))
    jobs = str(min(8, os.cpu_count() or 2))
    for name in ["lame", "opus", "libvpx", "ffmpeg"]:
        source = sources[name]
        suffix = ".tar.xz" if name == "ffmpeg" else ".tar.gz"
        archive = downloads / f"{name}-{source['version']}{suffix}"
        if not archive.exists():
            run(["curl", "--fail", "--location", "--retry", "2", "--max-time", "300",
                 source["url"], "-o", archive], root, environment)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != source["sha256"]:
            raise SystemExit(f"Incorrect source SHA-256: {archive}")
        source_directory = work / f"{name}-{source['version']}"
        if not source_directory.exists():
            # Extraction is allowed only after checking the pinned upstream archive.
            with tarfile.open(archive) as package:
                package.extractall(work, filter="data")
        build = work / f"build-{name}"
        build.mkdir(exist_ok=True)
        configure = source_directory / "configure"
        if name == "lame":
            options = [f"--prefix={prefix}", f"--host={host}-apple-darwin", "--disable-shared",
                       "--enable-static", "--disable-frontend", "--disable-decoder", "--disable-nasm"]
        elif name == "opus":
            options = [f"--prefix={prefix}", f"--host={host}-apple-darwin", "--disable-shared",
                       "--enable-static", "--disable-extra-programs", "--disable-doc"]
        elif name == "libvpx":
            # Portable Intel C code avoids a build-time NASM dependency and newer CPU requirements.
            target = "arm64-darwin23-gcc" if arch == "arm64" else "generic-gnu"
            options = [f"--prefix={prefix}", f"--target={target}", "--disable-shared", "--enable-static",
                       "--enable-pic", "--disable-examples", "--disable-tools", "--disable-docs",
                       "--disable-unit-tests", "--disable-x86-asm", "--disable-neon-asm"]
        else:
            options = [f"--prefix={prefix}", "--cc=clang", f"--arch={arch}", "--target-os=darwin",
                       "--enable-cross-compile", f"--sysroot={sdk}", f"--extra-cflags={flags} -I{prefix / 'include'}",
                       f"--extra-ldflags={flags} -L{prefix / 'lib'}", "--pkg-config-flags=--static",
                       "--disable-autodetect", "--disable-shared", "--enable-static", "--enable-pic",
                       "--disable-gpl", "--disable-nonfree", "--disable-version3", "--disable-doc",
                       "--disable-debug", "--disable-ffplay", "--disable-indevs", "--disable-outdevs",
                       "--enable-indev=lavfi", "--disable-network",
                       "--disable-x86asm", "--disable-protocols", "--enable-protocol=file,pipe,fd",
                       "--enable-libvpx", "--enable-libopus", "--enable-libmp3lame"]
        run([configure, *options], build, environment)
        run(["make", f"-j{jobs}"], build, environment)
        run(["make", "install"], build, environment)
    tools = output / "Tools"
    tools.mkdir(parents=True, exist_ok=True)
    for name in ["ffmpeg", "ffprobe"]:
        executable = tools / name
        shutil.copy2(prefix / "bin" / name, executable)
        run(["lipo", executable, "-verify_arch", arch], root, environment)
        libraries = subprocess.check_output(["otool", "-L", executable], text=True)
        if any(not line.strip().startswith(("/usr/lib/", "/System/Library/"))
               for line in libraries.splitlines()[1:]):
            raise SystemExit(f"Non-system runtime dependency in {executable}: {libraries}")
    media_cache.record(root, arguments.arch, work)
    print(f"Built {tools}", flush=True)


if __name__ == "__main__":
    main()
