import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export const packageInfo = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));
export const releaseInfo = JSON.parse(readFileSync(new URL('./release.json', import.meta.url), 'utf8'));
export const repository = 'StPashik/Yuzu-converter';

export function validateRelease(manifest) {
  if (manifest.version !== packageInfo.version || manifest.repository !== repository) {
    throw new Error('The release manifest must match this package version and repository.');
  }
  for (const arch of packageInfo.cpu) {
    const asset = manifest.assets?.[arch];
    if (asset?.name !== `Yuzu-Converter-${packageInfo.version}-${arch}.zip` || !/^[a-f0-9]{64}$/.test(asset?.sha256 ?? '')) {
      throw new Error(`No pinned ${arch} release. Build the application archive and run npm run prepare:release before npm pack.`);
    }
  }
  if (Object.keys(manifest.assets).some(arch => !packageInfo.cpu.includes(arch))) {
    throw new Error('The release manifest contains unsupported architectures.');
  }
  return manifest;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    validateRelease(releaseInfo);
    console.log(`Release ${packageInfo.version}: pinned SHA-256 checksums verified for ${packageInfo.cpu.join(', ')}.`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
