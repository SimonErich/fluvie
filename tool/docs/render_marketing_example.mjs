// Render the exact compiled source displayed on the site and publish its proof.
import { execFileSync, spawn } from 'node:child_process';
import { openSync, closeSync } from 'node:fs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { publishedProof } from './rendered_example.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
execFileSync('node', ['tool/docs/sync_reference.mjs', '--skip-rendered-proof'], { cwd: root, stdio: 'inherit' });
const evidence = join(root, 'build/marketing');
await mkdir(evidence, { recursive: true });
const media = join(root, 'web/site/public/media');
const log = openSync(join(evidence, 'promo.render.jsonl'), 'w');
try {
  const arguments_ = ['--packages=.dart_tool/package_config.json', 'packages/fluvie_cli/bin/fluvie.dart',
    'render', join(media, 'promo.dart'), '--project', join(root, 'examples/gallery'),
    '--out', join(media, 'promo.mp4'), '--no-cache', '--machine'];
  if (process.env.FLUVIE_FFMPEG) arguments_.push('--ffmpeg', process.env.FLUVIE_FFMPEG);
  const child = spawn('dart', arguments_, { cwd: root, stdio: ['ignore', log, log] });
  const code = await new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('exit', resolve);
  });
  if (code !== 0) throw new Error(`Marketing render failed (${code}); see build/marketing/promo.render.jsonl`);
} finally {
  closeSync(log);
}
const full = await readFile(join(media, 'promo.render.json'), 'utf8');
await writeFile(join(evidence, 'promo.full.render.json'), full);
const [source, video, poster] = await Promise.all(['promo.dart', 'promo.mp4', 'promo.poster.png'].map((name) => readFile(join(media, name))));
const proof = publishedProof(JSON.parse(full), source, video, poster);
await writeFile(join(media, 'promo.render.json'), JSON.stringify(proof, null, 2) + '\n');
console.log(`Published actual ${proof.capture.frameCount}-frame render with source, poster and verified identities.`);
