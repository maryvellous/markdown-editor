import { copyFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

const source = resolve('node_modules', 'mermaid', 'dist', 'mermaid.min.js');
const target = resolve('src', 'vendor', 'mermaid.min.js');

await mkdir(dirname(target), { recursive: true });
await copyFile(source, target);

console.log('Mermaid runtime copiato in src/vendor/mermaid.min.js');
