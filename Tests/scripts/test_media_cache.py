"""Cache receipts must reject stale or partial builds before any helper is reused."""

import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
import media_cache


class MediaCacheTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output = self.root / '.build/media-arm64'
        self.work = self.root / 'temporary-runner-build'
        self.patches = [patch.object(media_cache, 'toolchain', return_value={'sdk': '26.0', 'clang': 'fixture'}),
                        patch.object(media_cache, 'verify_tools')]
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)
        for name in ['scripts/build-media.py', 'scripts/media_cache.py']:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('fixture build recipe')
        manifest = {}
        for name in ['lame', 'opus', 'libvpx', 'ffmpeg']:
            suffix = '.tar.xz' if name == 'ffmpeg' else '.tar.gz'
            path = self.root / f'.build/media-sources/{name}-1{suffix}'
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(name.encode())
            manifest[name] = {'version': '1', 'sha256': media_cache.sha256(path)}
        (self.root / 'Resources').mkdir()
        (self.root / 'Resources/Media-sources.json').write_text(json.dumps(manifest))
        for name in media_cache.CONFIGURATIONS:
            path = self.work / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('actual configuration: ' + name)
        for name in ['ffmpeg', 'ffprobe']:
            path = self.output / 'Tools' / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(name.encode())
        media_cache.record(self.root, 'arm64', self.work)

    def test_complete_build_is_portable_after_original_work_directory_is_removed(self):
        import shutil
        shutil.rmtree(self.work)
        self.assertTrue(media_cache.verify(self.root, 'arm64'))
        self.assertEqual(len(json.loads((self.output / 'receipt.json').read_text())['files']), 9)

    def test_recipe_manifest_architecture_and_toolchain_invalidate_key(self):
        original = media_cache.key(self.root, 'arm64')
        self.assertNotEqual(original, media_cache.key(self.root, 'x64'))
        for name in ['scripts/build-media.py', 'scripts/media_cache.py', 'Resources/Media-sources.json']:
            path = self.root / name
            contents = path.read_bytes()
            path.write_bytes(contents + b'\n')
            self.assertNotEqual(original, media_cache.key(self.root, 'arm64'))
            self.assertFalse(media_cache.verify(self.root, 'arm64'))
            path.write_bytes(contents)
        with patch.object(media_cache, 'toolchain', return_value={'sdk': '26.1', 'clang': 'fixture'}):
            self.assertNotEqual(original, media_cache.key(self.root, 'arm64'))
            self.assertFalse(media_cache.verify(self.root, 'arm64'))

    def test_corrupt_tool_or_configuration_is_rejected(self):
        for name in media_cache.FILES:
            path = self.output / name
            original = path.read_bytes()
            path.write_bytes(b'corrupt')
            self.assertFalse(media_cache.verify(self.root, 'arm64'), name)
            path.write_bytes(original)
        self.assertTrue(media_cache.verify(self.root, 'arm64'))

    def test_missing_configuration_and_malformed_receipt_are_rejected(self):
        (self.output / 'configurations' / media_cache.CONFIGURATIONS[0]).unlink()
        self.assertFalse(media_cache.verify(self.root, 'arm64'))
        (self.output / 'receipt.json').write_text('not JSON')
        self.assertFalse(media_cache.verify(self.root, 'arm64'))

    def test_receipt_cannot_add_or_substitute_paths(self):
        path = self.output / 'receipt.json'
        receipt = json.loads(path.read_text())
        receipt['files']['../../outside'] = hashlib.sha256(b'untrusted').hexdigest()
        path.write_text(json.dumps(receipt))
        self.assertFalse(media_cache.verify(self.root, 'arm64'))

    def test_upstream_sources_are_verified_on_cache_hit(self):
        path, _ = next(media_cache.source_archives(self.root))
        path.write_bytes(b'changed source')
        self.assertFalse(media_cache.verify(self.root, 'arm64'))

    def test_even_a_matching_file_symlink_is_rejected(self):
        path = self.output / 'Tools/ffmpeg'
        outside = self.root / 'outside-tool'
        path.rename(outside)
        path.symlink_to(outside)
        self.assertFalse(media_cache.verify(self.root, 'arm64'))

    def test_runtime_architecture_or_dependency_failure_is_rejected(self):
        with patch.object(media_cache, 'verify_tools', side_effect=ValueError('incorrect CPU')):
            self.assertFalse(media_cache.verify(self.root, 'arm64'))

    def test_missing_other_architecture_is_rejected(self):
        self.assertFalse(media_cache.verify(self.root, 'x64'))
