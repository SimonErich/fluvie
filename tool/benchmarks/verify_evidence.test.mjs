import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { verifyAuthoringEvidence } from './verify_evidence.mjs';

const directory = resolve(import.meta.dirname, '../../web/site/public/media/authoring');
const report = JSON.parse(readFileSync(resolve(directory, 'benchmark.json')));
test('recorded publication retains five real cases, eight exports and their exact source bytes', () => {
  assert.deepEqual(verifyAuthoringEvidence(report, directory), { cases: 5, exports: 8 });
});
test('publication rejects tampered source, bundle, poster and rendered page code', () => {
  for (const name of [report.cases[0].sourcePath, report.bundle.path, report.cases[0].posterPath]) {
    assert.throws(() => verifyAuthoringEvidence(report, directory,
      (path) => path === resolve(directory, name) ? Buffer.from('changed') : readFileSync(path)), /hash|identity/);
  }
  const stale = structuredClone(report);
  stale.cases[0].sourceText = 'different code displayed on the page';
  assert.throws(() => verifyAuthoringEvidence(stale, directory), /source/);
  assert.throws(() => verifyAuthoringEvidence({ ...report, realProvider: false }, directory), /recorded/);
});
