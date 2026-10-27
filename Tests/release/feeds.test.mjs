import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash, generateKeyPairSync, sign } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { verifyAppcast } from '../../scripts/verify-update-feeds.mjs';

const keys = generateKeyPairSync('ed25519');
function fixture({ arch = 'arm64', url, version = '1.2.3', build = '9', signature = Buffer.alloc(64).toString('base64') } = {}) {
  const destination = url ?? `https://github.com/StPashik/Yuzu-converter/releases/download/v${version}/Yuzu-Converter-${version}-${arch}.zip`;
  const bytes = Buffer.from(`<?xml version="1.0"?><rss><channel><item><title>Yuzu — update</title><sparkle:version>${build}</sparkle:version><sparkle:shortVersionString>${version}</sparkle:shortVersionString><enclosure url="${destination}" sparkle:edSignature="${signature}" length="1024"/></item></channel></rss>`);
  return Buffer.concat([bytes, Buffer.from(`<!-- sparkle-signatures:\nedSignature: ${sign(null, bytes, keys.privateKey).toString('base64')}\nlength: ${bytes.length}\n-->\n`)]);
}

test('signed feeds retain Unicode byte lengths and architecture-specific release URLs', () => {
  for (const arch of ['arm64', 'x64']) {
    const result = verifyAppcast(fixture({ arch }), arch, keys.publicKey);
    assert.equal(result.version, '1.2.3');
    assert.equal(result.build, '9');
    assert.equal(result.length, 1024);
    assert.ok(result.url.endsWith(`-${arch}.zip`));
  }
});

test('tampered feeds, incorrect keys, and modified signed lengths are rejected', () => {
  const bytes = fixture();
  assert.throws(() => verifyAppcast(Buffer.from(bytes.toString().replace('Yuzu — update', 'Yuzu — changed')), 'arm64', keys.publicKey), /signature|length/);
  assert.throws(() => verifyAppcast(bytes, 'arm64', generateKeyPairSync('ed25519').publicKey), /signature/);
  assert.throws(() => verifyAppcast(Buffer.from(bytes.toString().replace(/length: \d+/, 'length: 1')), 'arm64', keys.publicKey), /length/);
});

test('even signed metadata cannot point at a foreign repository or the wrong CPU', () => {
  assert.throws(() => verifyAppcast(fixture({ url: 'https://example.invalid/app.zip' }), 'arm64', keys.publicKey), /repository/);
  assert.throws(() => verifyAppcast(fixture(), 'x64', keys.publicKey), /architecture/);
  assert.throws(() => verifyAppcast(fixture({ build: '0' }), 'arm64', keys.publicKey), /metadata/);
  assert.throws(() => verifyAppcast(fixture({ signature: 'invalid' }), 'arm64', keys.publicKey), /signature/);
});

test('the repository legacy feeds verify with the existing project public key', () => {
  const output = execFileSync(process.execPath, ['scripts/verify-update-feeds.mjs', 'updates', 'arm64', 'x64'], { encoding: 'utf8' });
  assert.match(output, /arm64: signed/);
  assert.match(output, /x64: signed 0\.4\.0 \/ build 7/);
  // Retired Intel clients must keep the exact last signed feed, not receive an arm64 update.
  const intel = readFileSync(new URL('../../updates/appcast-x64.xml', import.meta.url));
  assert.equal(createHash('sha256').update(intel).digest('hex'), 'b14db5ecc5b2c1eee9d83e5245b994e92de0f04ac1f30b57f161d3f856c3370b');
});
