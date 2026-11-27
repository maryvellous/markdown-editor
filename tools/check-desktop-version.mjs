import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const read = (path) => readFileSync(fileURLToPath(new URL('../' + path, import.meta.url)), 'utf8');
const json = (path) => JSON.parse(read(path));
const version = json('package.json').version;
const cargoVersion = read('src-tauri/Cargo.toml').match(/^version\s*=\s*"([^"]+)"/m)?.[1];
const cargoLock = read('src-tauri/Cargo.lock').match(/^\[\[package\]\]\r?\nname = "diaspro-markdown"\r?\nversion = "([^"]+)"/m)?.[1];
const versions = {
  'package-lock.json': json('package-lock.json').version,
  'package-lock.json root': json('package-lock.json').packages[''].version,
  'src-tauri/Cargo.toml': cargoVersion,
  'src-tauri/Cargo.lock': cargoLock,
  'src-tauri/tauri.conf.json': json('src-tauri/tauri.conf.json').version,
  'diaspro-installer.json': json('diaspro-installer.json').app.version,
};
if (!/^\d+\.\d+\.\d+$/.test(version)) throw Error('Invalid desktop version: ' + version);
for (const [path, value] of Object.entries(versions)) {
  if (value !== version) throw Error(path + ': expected ' + version + ', got ' + value);
}
if (process.env.GITHUB_REF?.startsWith('refs/tags/') && process.env.GITHUB_REF_NAME !== 'v' + version) {
  throw Error('Tag and desktop version differ');
}
console.log('Desktop version verified: ' + version);
