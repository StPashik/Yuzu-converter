import { readFile, writeFile, mkdir, stat } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { createHash, createPublicKey, verify } from 'node:crypto';
import { packageInfo, releaseInfo, repository, validateRelease } from '../npm/validate-release.mjs';

const run = promisify(execFile);
const directory = resolve(process.argv[2] ?? 'dist');
const tools = resolve('.build/verification/artifacts/sparkle/Sparkle/bin');
const account = 'com.stpashik.yuzu-converter';
const releaseURL = `https://github.com/${repository}/releases/tag/v${packageInfo.version}`;
const value = async key => (await run('/usr/bin/plutil', ['-extract', key, 'raw', '-o', '-', 'Resources/Info.plist'])).stdout.trim();
const build = await value('CFBundleVersion');
const publicBytes = Buffer.from(await value('SUPublicEDKey'), 'base64');
if (publicBytes.length !== 32) throw new Error('A valid Sparkle public key is required.');
// Node expects SPKI metadata around the raw Ed25519 key stored in Info.plist.
const key = createPublicKey({ key: Buffer.concat([Buffer.from('302a300506032b6570032100', 'hex'), publicBytes]), type: 'spki', format: 'der' });
validateRelease(releaseInfo);
await mkdir(directory, { recursive: true });

for (const arch of ['arm64', 'x64']) {
  const asset = releaseInfo.assets[arch];
  const path = join(directory, asset.name);
  const bytes = await readFile(path);
  if (createHash('sha256').update(bytes).digest('hex') !== asset.sha256) throw new Error(`Rebuild the npm manifest for ${arch}.`);
  const signature = (await run(join(tools, 'sign_update'), ['--account', account, '-p', path])).stdout.trim();
  // Independently verify Sparkle's output against the key embedded in the app before publishing it.
  if (!verify(null, bytes, key, Buffer.from(signature, 'base64'))) throw new Error(`Incorrect update signing key for ${arch}.`);
  const url = `https://github.com/${repository}/releases/download/v${packageInfo.version}/${asset.name}`;
  const feed = `<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Yuzu Converter Updates</title>
    <link>${releaseURL}</link>
    <description>Signed ${arch} updates for Yuzu Converter.</description>
    <item>
      <title>Yuzu Converter ${packageInfo.version}</title>
      <sparkle:version>${build}</sparkle:version>
      <sparkle:shortVersionString>${packageInfo.version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <description><![CDATA[<p>Yuzu Converter ${packageInfo.version} is ready to install.</p><p><a href="${releaseURL}">Read the release notes on GitHub</a>.</p>]]></description>
      <enclosure url="${url}" sparkle:edSignature="${signature}" length="${(await stat(path)).size}" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
`;
  // Legacy main/updates feeds advance through a separate PR only after these assets are public.
  const destination = join(directory, `appcast-${arch}.xml`);
  await writeFile(destination, feed);
  await run(join(tools, 'sign_update'), ['--account', account, destination]);
  await run(join(tools, 'sign_update'), ['--account', account, '--verify', destination]);
  console.log(`${arch}: archive signature independently verified; feed signed and verified.`);
}
