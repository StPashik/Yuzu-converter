import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createPublicKey, verify } from 'node:crypto';
import { repository } from '../npm/validate-release.mjs';

function signatureBytes(value) {
  const bytes = Buffer.from(value ?? '', 'base64');
  if (bytes.length !== 64 || bytes.toString('base64') !== value) throw new Error('Invalid Ed25519 signature.');
  return bytes;
}

export function verifyAppcast(bytes, arch, key) {
  if (!['arm64', 'x64'].includes(arch) || bytes.length > 1024 * 1024) throw new Error('Invalid feed architecture or size.');
  const marker = bytes.lastIndexOf('<!-- sparkle-signatures:');
  if (marker < 0) throw new Error('The appcast has no signed footer.');
  const footer = bytes.subarray(marker).toString('utf8').match(/^<!-- sparkle-signatures:\nedSignature: (\S+)\nlength: (\d+)\n-->\n?$/);
  if (!footer || Number(footer[2]) !== marker || !verify(null, bytes.subarray(0, marker), key, signatureBytes(footer[1]))) {
    throw new Error('The appcast signature or signed length is invalid.');
  }
  const xml = bytes.subarray(0, marker).toString('utf8');
  const version = xml.match(/<sparkle:shortVersionString>([^<]+)<\/sparkle:shortVersionString>/)?.[1];
  const build = xml.match(/<sparkle:version>([^<]+)<\/sparkle:version>/)?.[1];
  const enclosure = xml.match(/<enclosure\b[^>]*>/)?.[0] ?? '';
  const url = enclosure.match(/\burl="([^"]+)"/)?.[1];
  const length = Number(enclosure.match(/\blength="(\d+)"/)?.[1]);
  const archiveSignature = enclosure.match(/sparkle:edSignature="([^"]+)"/)?.[1];
  if (!/^\d{1,6}\.\d{1,6}\.\d{1,6}$/.test(version ?? '') || !/^[1-9]\d{0,11}$/.test(build ?? '') ||
      (xml.match(/<item>/g) ?? []).length !== 1 || !Number.isSafeInteger(length) || length <= 0 || length > 1024 ** 3) {
    throw new Error('The appcast has invalid release metadata.');
  }
  const expected = `https://github.com/${repository}/releases/download/v${version}/Yuzu-Converter-${version}-${arch}.zip`;
  if (url !== expected) throw new Error('The appcast points to a different repository, version, or architecture.');
  signatureBytes(archiveSignature);
  return { version, build, url, length };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const directory = resolve(process.argv[2] ?? 'updates');
  const plist = await readFile(new URL('../Resources/Info.plist', import.meta.url), 'utf8');
  const raw = Buffer.from(plist.match(/<key>SUPublicEDKey<\/key>\s*<string>([^<]+)<\/string>/)?.[1] ?? '', 'base64');
  if (raw.length !== 32) throw new Error('Missing project update public key.');
  const key = createPublicKey({ key: Buffer.concat([Buffer.from('302a300506032b6570032100', 'hex'), raw]), type: 'spki', format: 'der' });
  // Legacy feeds can intentionally lag source versions until the new release assets are public.
  for (const arch of ['arm64', 'x64']) {
    const feed = verifyAppcast(await readFile(resolve(directory, `appcast-${arch}.xml`)), arch, key);
    console.log(`${arch}: signed ${feed.version} / build ${feed.build} feed and pinned download metadata verified`);
  }
}
