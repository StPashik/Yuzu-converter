#!/usr/bin/env node
import { execFile } from 'node:child_process';
import { install } from './install.mjs';
import { packageInfo } from './validate-release.mjs';

const argument = process.argv[2];
if (argument === '--version' || argument === '-v') {
  console.log(packageInfo.version);
} else if (argument === '--help' || argument === '-h') {
  console.log('Usage: yuzu-converter [--version | --help]\n\nInstall this release if needed, then launch Yuzu Converter from ~/Applications.\nRequires macOS 13 or later.');
} else if (argument) {
  console.error(`Unknown argument: ${argument}. Use --help.`);
  process.exitCode = 1;
} else {
  try {
    const path = await install();
    execFile('/usr/bin/open', [path], error => {
      if (error) {
        console.error(`Could not launch Yuzu Converter: ${error.message}`);
        process.exitCode = 1;
      }
    });
  } catch (error) {
    console.error(`Yuzu Converter: ${error.message}`);
    process.exitCode = 1;
  }
}
