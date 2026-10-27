#!/usr/bin/env python3
"""Independently inspect final ZIPs and execute their signed apps without developer media overrides."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--arch", choices=["arm64", "x64"], help="Verify one native CI architecture; the default verifies both.")
selected_arch = parser.parse_args().arch
version = json.loads((root / "package.json").read_text())["version"]
build = plistlib.loads((root / "Resources/Info.plist").read_bytes())["CFBundleVersion"]
environment = dict(os.environ, PATH="/usr/bin:/bin:/usr/sbin:/sbin",
                   YUZU_FFMPEG="/nonexistent/developer-ffmpeg", YUZU_FFPROBE="/nonexistent/developer-ffprobe")


def run(arguments, timeout=180):
    return subprocess.check_output(list(map(str, arguments)), env=environment, stderr=subprocess.STDOUT,
                                   text=True, timeout=timeout)


for arch, cpu in [("arm64", "arm64"), ("x64", "x86_64")]:
    if selected_arch and arch != selected_arch:
        continue
    path = root / f"dist/Yuzu-Converter-{version}-{arch}.zip"
    with zipfile.ZipFile(path) as archive:
        assert all(name.startswith("Yuzu Converter.app/") for name in archive.namelist())
    with tempfile.TemporaryDirectory(prefix=f"yuzu-media-release-{arch}-") as directory:
        run(["/usr/bin/ditto", "-x", "-k", "--norsrc", path, directory])
        app = Path(directory) / "Yuzu Converter.app"
        contents = app / "Contents"
        plist = plistlib.loads((contents / "Info.plist").read_bytes())
        assert plist["CFBundleShortVersionString"] == version and plist["CFBundleVersion"] == build
        assert plist["YuzuSandboxed"] is True
        assert plist["SUFeedURL"] == f"https://github.com/StPashik/Yuzu-converter/releases/latest/download/appcast-{arch}.xml"
        for setting in ["SUEnableAutomaticChecks", "SUAutomaticallyUpdate", "SUAllowsAutomaticUpdates", "SUEnableSystemProfiling"]:
            assert plist[setting] is False, setting
        assert plist["SUVerifyUpdateBeforeExtraction"] is True and plist["SURequireSignedFeed"] is True
        run(["/usr/bin/codesign", "--verify", "--deep", "--strict", app])
        for tool in ["ffmpeg", "ffprobe"]:
            helper = contents / "Helpers" / tool
            run(["/usr/bin/lipo", helper, "-verify_arch", cpu])
            load_commands = run(["/usr/bin/vtool", "-show-build", helper])
            assert re.search(r"\bminos 13\.0\b", load_commands), load_commands
            libraries = run(["/usr/bin/otool", "-L", helper]).splitlines()[1:]
            assert libraries and all(line.strip().startswith(("/usr/lib/", "/System/Library/")) for line in libraries)
            signature = run(["/usr/bin/codesign", "-d", "--entitlements", ":-", helper])
            start, end = signature.index("<?xml"), signature.index("</plist>") + len("</plist>")
            assert plistlib.loads(signature[start:end].encode()) == {
                "com.apple.security.app-sandbox": True, "com.apple.security.inherit": True}
        assert (contents / "Resources/Media-sources.json").read_bytes() == (root / "Resources/Media-sources.json").read_bytes()
        for pattern in ["FFmpeg-*", "LAME-*", "libvpx-*", "Opus-*"]:
            for license_path in (root / "docs/licenses").glob(pattern):
                assert (contents / "Resources/Media-Licenses" / license_path.name).read_bytes() == license_path.read_bytes()
        for language in ["en", "ru", "de", "fr", "es"]:
            assert (contents / f"Resources/{language}.lproj/Localizable.strings").read_bytes() == (
                root / f"Sources/YuzuApp/Resources/{language}.lproj/Localizable.strings").read_bytes()
        executable = contents / "MacOS/YuzuApp"
        prefix = ["/usr/bin/arch", "-x86_64"] if arch == "x64" else []
        assert run([*prefix, executable, "--version"]).strip() == version
        result = run([*prefix, executable, "--self-check"])
        assert "Sandbox self-check passed" in result, result
        print(result.strip(), flush=True)
        print(f"{arch}: final ZIP, signatures, helper entitlements, macOS target, dependencies, resources, and Sandbox media passed", flush=True)
