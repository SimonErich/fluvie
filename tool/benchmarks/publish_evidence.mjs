import { readFileSync, writeFileSync, mkdirSync, copyFileSync } from 'node:fs';
import { resolve, dirname, basename, join } from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { publishedRenderProof, verifyPublishedProof } from '../docs/rendered_example.mjs';

// Publish selected, integrity-checked facts rather than private model traces or
// the benchmark's absolute source/dependency paths.
const reportPath = process.argv[2];
const bundlePath = process.argv[3];
if (!reportPath || !bundlePath) throw new Error('Usage: node tool/benchmarks/publish_evidence.mjs <benchmark.json> <project.fluvie.zip>');
const report = JSON.parse(readFileSync(reportPath));
if (report.schemaVersion !== 1 || report.ok !== true || report.realProvider !== true) {
  throw new Error('Publish only a complete successful real-provider run.');
}
const root = resolve(import.meta.dirname, '../..');
const bundle = JSON.parse(execFileSync('dart', ['--packages=.dart_tool/package_config.json',
  'packages/fluvie_cli/bin/fluvie.dart', 'bundle', 'inspect', resolve(bundlePath), '--json'],
  { cwd: root, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }));
const output = join(root, 'web/site/public/media/authoring');
mkdirSync(output, { recursive: true });
const identity = (path) => {
  const bytes = readFileSync(path);
  return { byteLength: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex') };
};
const representative = (samples) => samples?.[Math.floor(samples.length / 2)];
const publishArtifact = (artifact, source, stem, inputPath, sample) => {
  const sourcePath = `${stem}.dart`, outputPath = `${stem}.mp4`, proofPath = `${stem}.proof.json`;
  const receipt = JSON.parse(readFileSync(artifact.receiptPath));
  const proof = publishedRenderProof(receipt, readFileSync(source), readFileSync(artifact.filePath),
    { sourcePath, outputPath, inputPath });
  copyFileSync(source, join(output, sourcePath));
  copyFileSync(artifact.filePath, join(output, outputPath));
  let posterPath = null;
  if (sample) {
    const rgba = execFileSync(receipt.toolchain.ffmpeg, ['-v', 'error', '-i', sample.filePath,
      '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgba', 'pipe:1'], { maxBuffer: 32 * 1024 * 1024 });
    if (sample.hashKind !== 'rgba' || createHash('sha256').update(rgba).digest('hex') !== sample.sha256) {
      throw new Error('Captured poster pixels differ from review evidence.');
    }
    posterPath = `${stem}.png`;
    proof.poster = { path: posterPath, ...identity(sample.filePath) };
    verifyPublishedProof(proof, readFileSync(source), readFileSync(artifact.filePath), readFileSync(sample.filePath));
    copyFileSync(sample.filePath, join(output, posterPath));
  }
  writeFileSync(join(output, proofPath), JSON.stringify(proof, null, 2) + '\n');
  return { sourcePath, outputPath, proofPath, posterPath, output: proof.output.media };
};
const cases = report.cases.map((task) => {
  if (!/^[a-z][a-z0-9_]{0,63}$/.test(task.id) || !task.ok || !task.renderVerified) {
    throw new Error('Invalid benchmark case or unverified export.');
  }
  const directory = join(dirname(resolve(reportPath)), task.id);
  const source = join(directory, 'after.dart');
  const artifact = task.review.artifact;
  const bundledSource = bundle.files.find((file) => file.path.startsWith('project/') &&
      file.path.endsWith('/' + basename(task.sourcePath)) && file.sha256 === identity(source).sha256);
  if (!bundle.verified || !bundledSource) {
    throw new Error('Replay bundle does not contain the recorded source.');
  }
  const { sourcePath, outputPath, proofPath, posterPath } = publishArtifact(artifact, source, task.id,
    basename(task.sourcePath), representative(task.review.samples));
  const beforePath = task.action === 'edit' || task.action === 'formats' ? `${task.id}.before.dart` : null;
  if (beforePath) copyFileSync(join(directory, 'before.dart'), join(output, beforePath));
  return { id: task.id, action: task.action, prompt: readFileSync(join(directory, 'prompt.txt'), 'utf8'),
    sourceText: readFileSync(source, 'utf8'), beforeText: beforePath ? readFileSync(join(directory, 'before.dart'), 'utf8') : null,
    elapsedMilliseconds: task.elapsedMilliseconds, sourcePath, outputPath, beforePath,
    proofPath, posterPath, bundleSourcePath: bundledSource.path,
    source: identity(source), output: identity(artifact.filePath),
    sourceRevision: artifact.sourceFingerprint,
    preserved: task.preserved, requiredSourceTextPresent: task.requiredSourceTextPresent,
    repeatableSelectedFrames: task.review.determinism?.ok === true,
    quality: task.review.quality,
    verification: artifact.verification,
    formats: (task.formats ?? []).map((format) => {
      if (!['square', 'reels', 'landscape'].includes(format.aspect) || !format.ok ||
          format.report.artifact.verification?.ok !== true) throw new Error('Unverified format export.');
      return { aspect: format.aspect, quality: format.report.quality, ...publishArtifact(format.report.artifact, source,
        `${task.id}_${format.aspect}`, basename(task.sourcePath), representative(format.report.samples)) };
    }),
  };
});
copyFileSync(bundlePath, join(output, 'project.fluvie.zip'));
const published = { schemaVersion: 1, provider: report.provider, model: report.model,
  realProvider: true, cases, bundle: { path: 'project.fluvie.zip', ...identity(bundlePath) },
  visualQuality: 'requires_human_review',
  scope: 'A recorded authoring benchmark with synthetic geometry and tones. Source preservation, selected-frame repeatability and encoded output are checked. Source references do not prove semantic asset selection. Provider identity is recorded, not authenticated.' };
writeFileSync(join(output, 'benchmark.json'), JSON.stringify(published, null, 2) + '\n');
writeFileSync(join(root, 'web/site/src/data/authoring-proof.json'), JSON.stringify(published, null, 2) + '\n');
process.stdout.write(`Published ${cases.length} verified authoring cases.\n`);
