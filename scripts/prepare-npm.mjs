import { createReadStream } from 'node:fs';
import { readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { packageInfo, repository } from '../npm/validate-release.mjs';

const directory = resolve(process.argv[2] ?? 'dist');
const manifest = { version: packageInfo.version, repository, assets: {} };

// Pin the final archives; rebuilding an app afterwards requires regenerating the npm package.
for (const arch of packageInfo.cpu) {
  const name = `Yuzu-Converter-${packageInfo.version}-${arch}.zip`;
  const digest = createHash('sha256');
  for await (const chunk of createReadStream(resolve(directory, name))) digest.update(chunk);
  manifest.assets[arch] = { name, sha256: digest.digest('hex') };
}

const packageOnDisk = JSON.parse(await readFile(new URL('../package.json', import.meta.url), 'utf8'));
if (packageOnDisk.version !== manifest.version) throw new Error('Package version changed while preparing the release.');
await writeFile(new URL('../npm/release.json', import.meta.url), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Pinned ${manifest.version} application archives from ${directory}.`);
