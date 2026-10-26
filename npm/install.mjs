import { createHash, timingSafeEqual } from 'node:crypto';
import { createReadStream, createWriteStream } from 'node:fs';
import { lstat, mkdir, mkdtemp, readdir, rename, rm } from 'node:fs/promises';
import { get } from 'node:https';
import { homedir, release as systemRelease } from 'node:os';
import { isAbsolute, join } from 'node:path';
import { pipeline } from 'node:stream/promises';
import { Transform } from 'node:stream';
import { promisify } from 'node:util';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { packageInfo, releaseInfo, repository, validateRelease } from './validate-release.mjs';

const run = promisify(execFile);
const appName = 'Yuzu Converter.app';
const bundleId = 'com.stpashik.yuzu-converter';
const maxArchiveBytes = 1024 * 1024 * 1024;
const downloadHosts = new Set(['github.com', 'release-assets.githubusercontent.com', 'objects.githubusercontent.com', 'github-releases.githubusercontent.com']);

async function statOrNull(path) {
  try { return await lstat(path); } catch (error) {
    if (error.code === 'ENOENT') return null;
    throw error;
  }
}

async function requireDirectory(path) {
  const info = await lstat(path);
  if (!info.isDirectory() || info.isSymbolicLink()) throw new Error(`Refusing a non-directory or symbolic link: ${path}`);
}

export function selectAsset(manifest, platform = process.platform, arch = process.arch) {
  if (platform !== 'darwin') throw new Error('Yuzu Converter requires macOS 13 or later.');
  if (!['arm64', 'x64'].includes(arch)) throw new Error(`Unsupported architecture: ${arch}`);
  validateRelease(manifest);
  return manifest.assets[arch];
}

export function validateDownloadURL(value) {
  const url = new URL(value);
  if (url.protocol !== 'https:' || !downloadHosts.has(url.hostname) || url.username || url.password || url.port) {
    throw new Error('The release download redirected outside the allowed GitHub HTTPS hosts.');
  }
  return url;
}

function responseFor(url, redirects = 0) {
  validateDownloadURL(url);
  return new Promise((resolve, reject) => {
    const request = get(url, { headers: { 'User-Agent': `yuzu-converter/${packageInfo.version}` } }, response => {
      if ([301, 302, 303, 307, 308].includes(response.statusCode)) {
        response.resume();
        if (redirects >= 5 || !response.headers.location) return reject(new Error('Too many or invalid release redirects.'));
        let next;
        try { next = validateDownloadURL(new URL(response.headers.location, url)); } catch (error) { return reject(error); }
        responseFor(next, redirects + 1).then(resolve, reject);
      } else if (response.statusCode === 200) {
        if (Number(response.headers['content-length'] ?? 0) > maxArchiveBytes) {
          response.destroy();
          return reject(new Error('The application archive is larger than the 1 GiB installation limit.'));
        }
        resolve(response);
      } else {
        response.resume();
        reject(new Error(`Could not download this release (HTTP ${response.statusCode}).`));
      }
    });
    request.setTimeout(30000, () => request.destroy(new Error('The release download stopped responding.')));
    request.on('error', reject);
  });
}

async function download(url, destination) {
  const response = await responseFor(url);
  let bytes = 0;
  const limit = new Transform({
    transform(chunk, encoding, done) {
      bytes += chunk.length;
      done(bytes > maxArchiveBytes ? new Error('The application archive exceeded the 1 GiB limit.') : null, chunk);
    }
  });
  await pipeline(response, limit, createWriteStream(destination, { flags: 'wx', mode: 0o600 }));
}

export async function verifyChecksum(path, expected) {
  if (!/^[a-f0-9]{64}$/.test(expected ?? '')) throw new Error('Missing or invalid pinned SHA-256.');
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  if (!timingSafeEqual(hash.digest(), Buffer.from(expected, 'hex'))) {
    throw new Error('The application archive failed SHA-256 verification. No application was replaced.');
  }
}

async function tool(command, args) {
  const result = await run(command, args, { maxBuffer: 16 * 1024 * 1024, timeout: 120000, env: { ...process.env, LANG: 'C', LC_ALL: 'C' } });
  return result.stdout.trim();
}

export function validateArchivePaths(names) {
  if (!names.length || names.length > 100000) throw new Error('Invalid archive file count.');
  for (const name of names) {
    const parts = name.split('/');
    if (parts[0] !== appName || parts.some(part => part === '..' || part === '.') || /[\\\u0000-\u001f\u007f]/.test(name)) {
      throw new Error(`Unsafe application archive path: ${JSON.stringify(name)}`);
    }
  }
}

async function validateArchive(path) {
  const names = (await tool('/usr/bin/unzip', ['-Z1', path])).split('\n');
  validateArchivePaths(names);
  const listing = await tool('/usr/bin/zipinfo', ['-l', path]);
  const entries = listing.split('\n').filter(line => /^[^ ]{10}\s/.test(line));
  // ditto would otherwise follow an archive symlink before we could inspect the extracted tree.
  if (entries.length !== names.length || entries.some(line => !/^[-d][rwxstST?-]{9}\s/.test(line))) {
    throw new Error('Application archives may contain only regular files and directories.');
  }
  const totals = listing.match(/(\d+) files?, (\d+) bytes uncompressed/);
  if (!totals || Number(totals[1]) !== names.length || Number(totals[2]) > maxArchiveBytes) {
    throw new Error('Invalid or oversized expanded application archive.');
  }
}

async function validateApplication(path, expectedVersion) {
  for (const directory of [path, join(path, 'Contents'), join(path, 'Contents', 'MacOS')]) await requireDirectory(directory);
  const plist = join(path, 'Contents', 'Info.plist');
  const executable = join(path, 'Contents', 'MacOS', 'YuzuApp');
  for (const file of [plist, executable]) {
    const info = await lstat(file);
    if (!info.isFile() || info.isSymbolicLink()) throw new Error(`Refusing a non-regular application file: ${file}`);
  }
  if (!((await lstat(executable)).mode & 0o111)) throw new Error('The application executable has no execute permission.');
  for (const [key, expected] of [['CFBundleIdentifier', bundleId], ['CFBundleExecutable', 'YuzuApp']]) {
    if (await tool('/usr/bin/plutil', ['-extract', key, 'raw', '-o', '-', plist]) !== expected) {
      throw new Error(`Refusing to replace or install an application with an unexpected ${key}.`);
    }
  }
  const version = await tool('/usr/bin/plutil', ['-extract', 'CFBundleShortVersionString', 'raw', '-o', '-', plist]);
  if (expectedVersion && version !== expectedVersion) throw new Error('The application version does not match the npm package.');
  return version;
}

export function applicationPath(home = homedir()) {
  if (!isAbsolute(home)) throw new Error('The installation home must be an absolute path.');
  return join(home, 'Applications', appName);
}

export async function install({ manifest = releaseInfo, home = homedir(), platform = process.platform, arch = process.arch, fetchAsset = download, log = console.log } = {}) {
  const asset = selectAsset(manifest, platform, arch);
  if (platform === process.platform && Number(systemRelease().split('.')[0]) < 22) throw new Error('Yuzu Converter requires macOS 13 or later.');
  const destination = applicationPath(home);
  const applications = join(home, 'Applications');
  await requireDirectory(home);
  await mkdir(applications, { recursive: true });
  await requireDirectory(applications);
  const current = await statOrNull(destination);
  if (current && await validateApplication(destination) === manifest.version) {
    log(`Yuzu Converter ${manifest.version} is already installed in ${destination}.`);
    return destination;
  }

  const stage = await mkdtemp(join(applications, '.yuzu-install-'));
  const archive = join(stage, asset.name);
  const previous = join(stage, 'previous.app');
  let movedPrevious = false;
  let preserveBackup = false;
  try {
    log(`Downloading Yuzu Converter ${manifest.version} for ${arch}…`);
    await fetchAsset(`https://github.com/${repository}/releases/download/v${manifest.version}/${asset.name}`, archive);
    await verifyChecksum(archive, asset.sha256);
    await validateArchive(archive);
    await tool('/usr/bin/ditto', ['-x', '-k', '--norsrc', archive, stage]);
    const prepared = join(stage, appName);
    await validateApplication(prepared, manifest.version);
    if ((await readdir(stage)).some(name => ![asset.name, appName].includes(name))) throw new Error('Unexpected extracted archive contents.');

    // Both renames stay on the destination volume; the previous app remains recoverable until publication succeeds.
    if (current) {
      await validateApplication(destination);
      await rename(destination, previous);
      movedPrevious = true;
    } else if (await statOrNull(destination)) {
      throw new Error('An application appeared at the installation path. Run the installer again.');
    }
    try {
      await rename(prepared, destination);
    } catch (error) {
      if (movedPrevious) {
        try { await rename(previous, destination); } catch {
          preserveBackup = true;
          throw new Error(`Installation failed. Your previous application is preserved at ${previous}.`, { cause: error });
        }
      }
      throw error;
    }
    log(`Installed ${destination}. Run yuzu-converter to launch.`);
    return destination;
  } finally {
    if (!preserveBackup) await rm(stage, { recursive: true, force: true });
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  install().catch(error => {
    console.error(`Yuzu Converter: ${error.message}`);
    process.exitCode = 1;
  });
}
