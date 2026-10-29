#!/usr/bin/env python3
"""Run real Sparkle checks against a local HTTP feed; never launch/install the fixture app."""
import argparse
import platform
import http.server
import base64
import json
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import threading
import uuid

root = pathlib.Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--arch", choices=["arm64", "x64"], default="arm64" if platform.machine() == "arm64" else "x64")
arch = parser.parse_args().arch
cpu = "arm64" if arch == "arm64" else "x86_64"
app = root / f"dist/stage-{arch}/Yuzu Converter.app"
frameworks = app / "Contents/Frameworks"
prefix = ["/usr/bin/arch", "-" + cpu]
probes = {}
for source in ["FeedProbe", "StartupProbe"]:
    probe = root / f".build/{source}-{arch}"
    subprocess.run(["swiftc", "-parse-as-library", "-target", f"{cpu}-apple-macosx13.0",
                    "-module-cache-path", str(root / f".build/probe-cache-{arch}"),
                    "-F", str(frameworks), "-framework", "Sparkle", "-Xlinker", "-rpath", "-Xlinker", str(frameworks),
                    str(root / f"Tests/updater/{source}.swift"), "-o", str(probe)], check=True)
    probes[source] = probe
feed = b""
requests = []


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        requests.append(self.path)
        self.send_response(500 if self.path == "/unavailable.xml" else 200)
        self.send_header("Content-Type", "application/rss+xml")
        self.end_headers()
        body = feed.replace(b"Yuzu Converter Updates", b"Tampered feed") if self.path == "/tampered.xml" else feed
        self.wfile.write(body)

    def log_message(self, *args):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
identifier = "com.stpashik.yuzu-converter.probe." + uuid.uuid4().hex
try:
    with tempfile.TemporaryDirectory(prefix="yuzu-update-probe-") as directory:
        fixture = pathlib.Path(directory) / "Yuzu Converter.app"
        shutil.copytree(app, fixture, symlinks=True)
        plist = fixture / "Contents/Info.plist"
        info = plistlib.loads(plist.read_bytes())
        build = int(info["CFBundleVersion"])
        assert info["SUEnableAutomaticChecks"] is True
        assert info["SUAutomaticallyUpdate"] is False and info["SUAllowsAutomaticUpdates"] is False
        info["CFBundleIdentifier"] = identifier
        # Test keys are temporary and unrelated to the owner's Keychain/release signing key.
        key_generator = """
const { generateKeyPairSync } = require('node:crypto');
const pair = generateKeyPairSync('ed25519');
process.stdout.write(JSON.stringify(pair.privateKey.export({ format: 'jwk' })));
"""
        key = json.loads(subprocess.run(["node", "-e", key_generator], check=True, capture_output=True, text=True).stdout)

        def decode(value):
            return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))

        private_key = pathlib.Path(directory) / "test-key"
        private_key.write_bytes(base64.b64encode(decode(key["d"])))
        private_key.chmod(0o600)
        info["SUPublicEDKey"] = base64.b64encode(decode(key["x"])).decode()
        xml = pathlib.Path(directory) / "feed.xml"
        signature = base64.b64encode(bytes(64)).decode()
        xml.write_text(f'''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
<title>Yuzu Converter Updates</title><item><title>Update fixture</title>
<sparkle:version>{build}</sparkle:version><sparkle:shortVersionString>{info['CFBundleShortVersionString']}</sparkle:shortVersionString>
<sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
<description sparkle:format="markdown"><![CDATA[## What changed
- PDF crop and rotation fixture.
]]></description>
<enclosure url="http://127.0.0.1:{server.server_port}/must-not-download.zip" sparkle:edSignature="{signature}" length="1" type="application/octet-stream"/>
</item></channel></rss>''')
        signer = root / f".build/release-{arch}/artifacts/sparkle/Sparkle/bin/sign_update"
        subprocess.run([str(signer), "--ed-key-file", str(private_key), str(xml)], check=True, capture_output=True)
        feed = xml.read_bytes()
        for path, version, expected in [("/feed.xml", build - 1, "available"), ("/feed.xml", build, "current"),
                                         ("/tampered.xml", build - 1, "error"), ("/unavailable.xml", build - 1, "error")]:
            info["CFBundleVersion"] = str(version)
            info["SUFeedURL"] = f"http://127.0.0.1:{server.server_port}{path}"
            plist.write_bytes(plistlib.dumps(info))
            subprocess.run(["codesign", "--force", "--sign", "-", str(fixture)], check=True, capture_output=True)
            before = len(requests)
            subprocess.run([*prefix, str(probes["FeedProbe"]), str(fixture), expected, str(build), "PDF crop and rotation fixture."], check=True, timeout=30)
            assert path in requests[before:], "The probe did not reach the HTTP fixture"
            print(f"{path}: {expected}, actual HTTP request verified", flush=True)
        # One fixture identity proves that the Settings preference and skipped version survive process restarts.
        for mode, path, version, expected in [
            ("background", "/feed.xml", build - 1, "available"),
            ("background", "/feed.xml", build, "current"),
            ("background", "/unavailable.xml", build - 1, "error"),
            ("background", "/tampered.xml", build - 1, "error"),
            ("disable", "/feed.xml", build - 1, "disabled"),
            ("background", "/feed.xml", build - 1, "disabled"),
            ("manual", "/feed.xml", build - 1, "available"),
            ("background", "/feed.xml", build - 1, "disabled"),
            ("enable", "/feed.xml", build - 1, "available"),
            ("background", "/feed.xml", build - 1, "available"),
            ("skip", "/feed.xml", build - 1, "available"),
            ("background", "/feed.xml", build - 1, "current"),
            ("manual", "/feed.xml", build - 1, "available"),
        ]:
            info["CFBundleVersion"] = str(version)
            info["SUFeedURL"] = f"http://127.0.0.1:{server.server_port}{path}"
            plist.write_bytes(plistlib.dumps(info))
            subprocess.run(["codesign", "--force", "--sign", "-", str(fixture)], check=True, capture_output=True)
            before = len(requests)
            subprocess.run([*prefix, str(probes["StartupProbe"]), str(fixture), mode, expected, str(build)], check=True, timeout=30)
            assert (path in requests[before:]) == (expected != "disabled"), (mode, requests[before:])
            print(f"{arch}: startup {mode}/{expected}, persisted choice and HTTP behavior verified", flush=True)
        assert "/must-not-download.zip" not in requests, "A test attempted to download without user consent"

finally:
    server.shutdown()
    subprocess.run(["defaults", "delete", identifier], capture_output=True)
