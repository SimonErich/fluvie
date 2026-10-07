import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve, basename, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { verifyPublishedProof } from '../docs/rendered_example.mjs';

// Keep the published claims, downloadable bytes and rendered code in agreement.
export function verifyAuthoringEvidence(report, directory, read = readFileSync) {
  if (report.schemaVersion !== 1 || report.realProvider !== true ||
      !Array.isArray(report.cases) || report.cases.length === 0) throw new Error('Missing recorded authoring evidence');
  const file = (name) => {
    if (typeof name !== 'string' || basename(name) !== name || name.includes('\\')) throw new Error('Unsafe publication path');
    return read(join(directory, name));
  };
  const checkIdentity = (record, bytes) => {
    if (record.byteLength !== bytes.length || record.sha256 !== createHash('sha256').update(bytes).digest('hex')) {
      throw new Error('Published evidence hash/identity differs from recorded bytes');
    }
  };
  checkIdentity(report.bundle, file(report.bundle.path));
  let exports = 0;
  for (const task of report.cases) {
    const source = file(task.sourcePath);
    checkIdentity(task.source, source);
    checkIdentity(task.output, file(task.outputPath));
    if (source.toString('utf8') !== task.sourceText || task.verification?.ok !== true) {
      throw new Error('Published source or export verification differs');
    }
    if (task.beforePath && file(task.beforePath).toString('utf8') !== task.beforeText) throw new Error('Original source differs');
    for (const artifact of [task, ...task.formats]) {
      const proof = JSON.parse(file(artifact.proofPath));
      verifyPublishedProof(proof, file(artifact.sourcePath), file(artifact.outputPath),
        artifact.posterPath ? file(artifact.posterPath) : undefined);
      if (proof.source.sha256 !== task.source.sha256) throw new Error('Formats use different Dart source');
      exports++;
    }
  }
  return { cases: report.cases.length, exports };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const directory = resolve(import.meta.dirname, '../../web/site/public/media/authoring');
  const report = JSON.parse(readFileSync(join(directory, 'benchmark.json')));
  const pageData = JSON.parse(readFileSync(resolve(import.meta.dirname, '../../web/site/src/data/authoring-proof.json')));
  if (JSON.stringify(report) !== JSON.stringify(pageData)) throw new Error('Authoring page metadata is stale');
  const result = verifyAuthoringEvidence(report, directory);
  process.stdout.write(`Verified ${result.cases} recorded cases and ${result.exports} published exports.\n`);
}
