#!/usr/bin/env python3
"""Run real Sparkle checks against a local HTTP feed; never launch/install the fixture app."""
import http.server
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import threading
import uuid

root = pathlib.Path(__file__).resolve().parent.parent
app = root / "dist/stage-arm64/Yuzu Converter.app"
frameworks = app / "Contents/Frameworks"
probe = root / ".build/update-feed-probe"
subprocess.run(["swiftc", "-parse-as-library", "-module-cache-path", str(root / ".build/probe-cache"),
                "-F", str(frameworks), "-framework", "Sparkle", "-Xlinker", "-rpath", "-Xlinker", str(frameworks),
                str(root / "Tests/updater/FeedProbe.swift"), "-o", str(probe)], check=True)
feed = (root / "updates/appcast-arm64.xml").read_bytes()
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
        info["CFBundleIdentifier"] = identifier
        for path, version, expected in [("/feed.xml", build - 1, "available"), ("/feed.xml", build, "current"),
                                         ("/tampered.xml", build - 1, "error"), ("/unavailable.xml", build - 1, "error")]:
            info["CFBundleVersion"] = str(version)
            info["SUFeedURL"] = f"http://127.0.0.1:{server.server_port}{path}"
            plist.write_bytes(plistlib.dumps(info))
            subprocess.run(["codesign", "--force", "--sign", "-", str(fixture)], check=True, capture_output=True)
            before = len(requests)
            subprocess.run([str(probe), str(fixture), expected, str(build)], check=True, timeout=30)
            assert path in requests[before:], "The probe did not reach the HTTP fixture"
            print(f"{path}: {expected}, actual HTTP request verified", flush=True)
finally:
    server.shutdown()
    subprocess.run(["defaults", "delete", identifier], capture_output=True)
