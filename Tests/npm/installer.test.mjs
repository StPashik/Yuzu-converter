import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { copyFile, lstat, mkdir, mkdtemp, readFile, readdir, readlink, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';
import { execFile } from 'node:child_process';
import { applicationPath, install, selectAsset, validateArchivePaths, validateSparkleLinks, validateDownloadURL, verifyChecksum } from '../../npm/install.mjs';
import { packageInfo, validateRelease } from '../../npm/validate-release.mjs';

const run = promisify(execFile);
const native = { skip: process.platform !== 'darwin' };
const silent = () => {};
const currentVersion = packageInfo.version;

function manifestFor(bytes) {
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  return {
    version: currentVersion, repository: 'StPashik/Yuzu-converter',
    assets: Object.fromEntries(['arm64', 'x64'].map(arch => [arch, { name: `Yuzu-Converter-${currentVersion}-${arch}.zip`, sha256 }]))
  };
}

async function scratch(t) {
  const path = await mkdtemp(join(tmpdir(), 'yuzu-installer-test-'));
  t.after(() => rm(path, { recursive: true, force: true }));
  return path;
}

async function fixtureApp(path, version = currentVersion, id = 'com.stpashik.yuzu-converter') {
  await mkdir(join(path, 'Contents', 'MacOS'), { recursive: true });
  await writeFile(join(path, 'Contents', 'Info.plist'), `<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>${id}</string><key>CFBundleExecutable</key><string>YuzuApp</string><key>CFBundleShortVersionString</key><string>${version}</string></dict></plist>\n`);
  await writeFile(join(path, 'Contents', 'MacOS', 'YuzuApp'), '#!/bin/sh\nexit 0\n', { mode: 0o755 });
}

async function archiveApp(t, { id, symlinkTarget, configure } = {}) {
  const directory = await scratch(t);
  const app = join(directory, 'Yuzu Converter.app');
  await fixtureApp(app, currentVersion, id);
  if (symlinkTarget) await symlink(symlinkTarget, join(app, 'escape'));
  await configure?.(app);
  const archive = join(directory, 'app.zip');
  await run('/usr/bin/ditto', ['-c', '-k', '--norsrc', '--keepParent', app, archive]);
  return { archive, manifest: manifestFor(await readFile(archive)) };
}

async function testHome(t, existingVersion) {
  const home = await scratch(t);
  await mkdir(join(home, 'Applications'));
  if (existingVersion) await fixtureApp(applicationPath(home), existingVersion);
  return home;
}

function installFixture(home, fixture) {
  return install({
    home, manifest: fixture.manifest,
    fetchAsset: async (url, destination) => {
      assert.equal(url, `https://github.com/StPashik/Yuzu-converter/releases/download/v${currentVersion}/${fixture.manifest.assets[process.arch].name}`);
      await copyFile(fixture.archive, destination);
    },
    log: silent
  });
}

test('release assets are version-pinned for supported macOS architectures', () => {
  const manifest = manifestFor(Buffer.from('fixture'));
  assert.equal(selectAsset(manifest, 'darwin', 'arm64').name, `Yuzu-Converter-${currentVersion}-arm64.zip`);
  assert.equal(selectAsset(manifest, 'darwin', 'x64').name, `Yuzu-Converter-${currentVersion}-x64.zip`);
  assert.throws(() => selectAsset(manifest, 'linux', 'x64'), /macOS/);
  assert.throws(() => selectAsset(manifest, 'darwin', 'ia32'), /architecture/);
  assert.throws(() => validateRelease({ ...manifest, version: '999.0.0' }), /match/);
  assert.throws(() => validateRelease({ ...manifest, version: '0.1.0' }), /match/);
  assert.throws(() => validateRelease({ ...manifest, assets: { ...manifest.assets, arm64: { ...manifest.assets.arm64, sha256: null } } }), /pinned arm64/);
  assert.throws(() => validateRelease({ ...manifest, assets: { arm64: manifest.assets.arm64 } }), /pinned x64/);
  assert.throws(() => applicationPath('relative-home'), /absolute/);
});

test('only approved HTTPS GitHub download hosts can be followed', () => {
  assert.equal(validateDownloadURL('https://release-assets.githubusercontent.com/example').hostname, 'release-assets.githubusercontent.com');
  for (const url of ['http://github.com/file', 'https://github.com.evil.example/file', 'https://evil.example/file', 'https://user@github.com/file', 'https://github.com:8443/file', 'file:///tmp/file']) {
    assert.throws(() => validateDownloadURL(url), /allowed GitHub/);
  }
});

test('checksum mismatch is rejected before extraction', async t => {
  const directory = await scratch(t);
  const file = join(directory, 'archive.zip');
  await writeFile(file, 'original');
  await verifyChecksum(file, createHash('sha256').update('original').digest('hex'));
  await assert.rejects(verifyChecksum(file, '0'.repeat(64)), /SHA-256 verification/);
  await assert.rejects(verifyChecksum(file, null), /pinned SHA-256/);
});

test('archive paths cannot leave the application root', () => {
  validateArchivePaths(['Yuzu Converter.app/', 'Yuzu Converter.app/Contents/MacOS/YuzuApp']);
  for (const name of ['../escape', '/absolute', 'Other.app/file', 'Yuzu Converter.app/../escape', 'Yuzu Converter.app/./file', 'Yuzu Converter.app/back\\slash', 'Yuzu Converter.app/line\nbreak']) {
    assert.throws(() => validateArchivePaths([name]), /Unsafe/);
  }
  assert.throws(() => validateArchivePaths([]), /count/);
  assert.throws(() => validateArchivePaths(['Yuzu Converter.app/Contents/Frameworks/Sparkle.framework//Resources/payload']), /Unsafe/);
  assert.throws(() => validateArchivePaths(['Yuzu Converter.app/A', 'Yuzu Converter.app/a']), /Duplicate/);
});

test('only fixed Sparkle aliases are accepted and no member can write through them', () => {
  const link = 'Yuzu Converter.app/Contents/Frameworks/Sparkle.framework/Resources';
  validateSparkleLinks([link], new Map([[link, 'Versions/Current/Resources']]));
  for (const target of ['/tmp', '../../outside', 'Versions/Current/Resources\n']) {
    assert.throws(() => validateSparkleLinks([link], new Map([[link, target]])), /canonical Sparkle/);
  }
  assert.throws(() => validateSparkleLinks([link, link + '/payload'], new Map([[link, 'Versions/Current/Resources']])), /descends/);
});

test('a real archive preserves the approved framework links during installation', native, async t => {
  const fixture = await archiveApp(t, { configure: async app => {
    const framework = join(app, 'Contents/Frameworks/Sparkle.framework');
    await mkdir(join(framework, 'Versions/B'), { recursive: true });
    await writeFile(join(framework, 'Versions/B/Sparkle'), 'fixture');
    await symlink('B', join(framework, 'Versions/Current'));
    await symlink('Versions/Current/Sparkle', join(framework, 'Sparkle'));
  }});
  const home = await testHome(t);
  await installFixture(home, fixture);
  const link = join(applicationPath(home), 'Contents/Frameworks/Sparkle.framework/Sparkle');
  assert.equal(await readlink(link), 'Versions/Current/Sparkle');
  assert.equal(await readFile(link, 'utf8'), 'fixture');
});

test('a verified archive installs a complete app without launching it', native, async t => {
  const fixture = await archiveApp(t);
  const home = await testHome(t);
  assert.equal(await installFixture(home, fixture), applicationPath(home));
  assert.equal((await lstat(join(applicationPath(home), 'Contents', 'MacOS', 'YuzuApp'))).isFile(), true);
  assert.deepEqual(await readdir(join(home, 'Applications')), ['Yuzu Converter.app']);
  assert.equal((await lstat(fixture.archive)).isFile(), true);
});

test('an installed release is idempotent and does not download again', native, async t => {
  const home = await testHome(t, currentVersion);
  await install({ home, manifest: manifestFor(Buffer.from('unused')), log: silent, fetchAsset: () => assert.fail('must not download') });
  assert.deepEqual(await readdir(join(home, 'Applications')), ['Yuzu Converter.app']);
});

test('an older npm launcher preserves a newer in-app update', native, async t => {
  const [major, minor, patch] = currentVersion.split('.').map(Number);
  for (const version of [`${major}.${minor}.${patch + 1}`, `${major}.${minor + 10}.0`, `${major + 1}.0.0`]) {
    const home = await testHome(t, version);
    const oldPlist = await readFile(join(applicationPath(home), 'Contents/Info.plist'));
    await install({ home, manifest: manifestFor(Buffer.from('unused')), log: silent, fetchAsset: () => assert.fail('must not downgrade') });
    assert.deepEqual(await readFile(join(applicationPath(home), 'Contents/Info.plist')), oldPlist);
  }
});

test('an upgrade publishes the requested release and removes its own staging directory', native, async t => {
  const fixture = await archiveApp(t);
  const home = await testHome(t, '0.3.0');
  await installFixture(home, fixture);
  assert.ok((await readFile(join(applicationPath(home), 'Contents', 'Info.plist'), 'utf8')).includes(`<string>${currentVersion}</string>`));
  assert.deepEqual(await readdir(join(home, 'Applications')), ['Yuzu Converter.app']);
});

test('failed checksum leaves the installed application and its contents intact', native, async t => {
  const fixture = await archiveApp(t);
  const home = await testHome(t, '0.1.0');
  const oldPlist = await readFile(join(applicationPath(home), 'Contents', 'Info.plist'));
  fixture.manifest.assets[process.arch].sha256 = '0'.repeat(64);
  await assert.rejects(installFixture(home, fixture), /SHA-256 verification/);
  assert.deepEqual(await readFile(join(applicationPath(home), 'Contents', 'Info.plist')), oldPlist);
  assert.deepEqual(await readdir(join(home, 'Applications')), ['Yuzu Converter.app']);
});

test('a corrupt archive leaves the old application intact', native, async t => {
  const directory = await scratch(t);
  const archive = join(directory, 'broken.zip');
  const bytes = Buffer.from('not a zip archive');
  await writeFile(archive, bytes);
  const home = await testHome(t, '0.1.0');
  await assert.rejects(installFixture(home, { archive, manifest: manifestFor(bytes) }));
  assert.match(await readFile(join(applicationPath(home), 'Contents', 'Info.plist'), 'utf8'), /0\.1\.0/);
  assert.deepEqual(await readdir(join(home, 'Applications')), ['Yuzu Converter.app']);
});

test('a foreign bundle cannot replace the old application', native, async t => {
  const fixture = await archiveApp(t, { id: 'com.example.other' });
  const home = await testHome(t, '0.1.0');
  await assert.rejects(installFixture(home, fixture), /unexpected CFBundleIdentifier/);
  assert.match(await readFile(join(applicationPath(home), 'Contents', 'Info.plist'), 'utf8'), /0\.1\.0/);
});

test('an archive symlink is rejected before extraction', native, async t => {
  const outside = await scratch(t);
  await writeFile(join(outside, 'sentinel'), 'keep');
  const fixture = await archiveApp(t, { symlinkTarget: outside });
  const home = await testHome(t);
  await assert.rejects(installFixture(home, fixture), /symbolic links/);
  assert.equal(await readFile(join(outside, 'sentinel'), 'utf8'), 'keep');
  assert.deepEqual(await readdir(join(home, 'Applications')), []);
});

test('an existing symbolic link or foreign application is never overwritten', native, async t => {
  const fixture = await archiveApp(t);
  const home = await testHome(t);
  const outside = await scratch(t);
  await symlink(outside, applicationPath(home));
  await assert.rejects(installFixture(home, fixture), /symbolic link/);
  assert.equal((await lstat(applicationPath(home))).isSymbolicLink(), true);
  await rm(applicationPath(home));
  await fixtureApp(applicationPath(home), '0.1.0', 'com.example.other');
  await assert.rejects(installFixture(home, fixture), /unexpected CFBundleIdentifier/);
  assert.match(await readFile(join(applicationPath(home), 'Contents', 'Info.plist'), 'utf8'), /com\.example\.other/);
});

test('a symbolic link Applications directory is refused before any download', native, async t => {
  const home = await scratch(t);
  const outside = await scratch(t);
  await symlink(outside, join(home, 'Applications'));
  await assert.rejects(install({ home, manifest: manifestFor(Buffer.from('unused')), fetchAsset: () => assert.fail('must not download'), log: silent }), /symbolic link/);
  assert.deepEqual(await readdir(outside), []);
});
