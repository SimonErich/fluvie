import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

const context = {};
runInNewContext(await readFile(new URL('../../apps/slides/tool/browser_pixel_oracle.js', import.meta.url), 'utf8'), context);
const { referenceRgb, assertPixels, packI420, packRgba, assertNative } = context.FluvieBrowserPixelOracle;
function pixels() {
  return Uint8Array.from({ length: 32 * 32 * 4 }, (_, i) => i % 4 === 3 ? 255 : 80);
}

test('fixed color reference preserves legal black/white and distinguishes 601 from 709 red', () => {
  const constant = (y, u, v, matrix) => Array.from(referenceRgb(Uint8Array.from([y, y, y, y, u, v]), 2, 2, matrix, false).slice(0, 4));
  assert.deepEqual(constant(16, 128, 128, 'bt709'), [0, 0, 0, 255]);
  assert.deepEqual(constant(235, 128, 128, 'bt709'), [255, 255, 255, 255]);
  assert.deepEqual(constant(81, 90, 240, 'bt601'), [254, 0, 0, 255]);
  assert.deepEqual(constant(81, 90, 240, 'bt709'), [255, 24, 0, 255]);
});

test('RGB oracle preserves strict color and opacity checks across the entire frame', () => {
  const reference = pixels();
  assert.equal(assertPixels(reference, reference, 32, 32, 'identical').area8Rms, 0);
  const color = reference.slice();
  for (let i = 0; i < color.length; i += 4) color[i] += 12;
  assert.throws(() => assertPixels(color, reference, 32, 32, 'wrong matrix'), /colors differ/);
  const missing = reference.slice();
  for (let i = 16 * 32 * 4; i < missing.length; i++) if (i % 4 !== 3) missing[i] = 0;
  assert.throws(() => assertPixels(missing, reference, 32, 32, 'missing lower rows'), /colors differ/);
  const alpha = reference.slice(); alpha[3] = 0;
  assert.throws(() => assertPixels(alpha, reference, 32, 32, 'alpha'), /lost alpha/);
});

test('averaging cannot hide corruption of flat pixels', () => {
  const reference = pixels(), checker = reference.slice();
  for (let i = 0; i < checker.length; i++) if (i % 4 !== 3) checker[i] += Math.floor(i / 4) % 2 ? 8 : -8;
  assert.throws(() => assertPixels(checker, reference, 32, 32, 'cancelled area errors'), /colors differ/);
});

test('I420 and NV12 with stride padding pack to the same canonical planes', () => {
  const expected = Uint8Array.from([1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 21, 22]);
  const i420 = Uint8Array.from([1, 2, 3, 4, 99, 99, 5, 6, 7, 8, 99, 99, 11, 12, 99, 21, 22]);
  const nv12 = Uint8Array.from([1, 2, 3, 4, 99, 99, 5, 6, 7, 8, 99, 99, 11, 21, 12, 22]);
  assertNative(packI420(i420, [{ offset: 0, stride: 6 }, { offset: 12, stride: 3 }, { offset: 15, stride: 3 }], 'I420', 4, 2), expected, 'I420');
  assertNative(packI420(nv12, [{ offset: 0, stride: 6 }, { offset: 12, stride: 6 }], 'NV12', 4, 2), expected, 'NV12');
  const corrupt = expected.slice(); corrupt[11]++;
  assert.throws(() => assertNative(corrupt, expected, 'one byte'), /byte 11/);
  assert.throws(() => packI420(new Uint8Array(1), [{ offset: 0, stride: 6 }, { offset: 12, stride: 6 }], 'NV12', 4, 2), /exceeds/);
});

test('native RGB channel order and row stride are preserved, with X made opaque', () => {
  const bgrx = Uint8Array.from([30, 20, 10, 0, 99, 99, 60, 50, 40, 0]);
  assert.deepEqual(Array.from(packRgba(bgrx, [{ offset: 0, stride: 6 }], 'BGRX', 1, 2)), [10, 20, 30, 255, 40, 50, 60, 255]);
  assert.deepEqual(Array.from(packRgba(Uint8Array.from([1, 2, 3, 4]), [{ offset: 0, stride: 4 }], 'RGBA', 1, 1)), [1, 2, 3, 4]);
  assert.throws(() => packRgba(new Uint8Array(3), [{ offset: 0, stride: 4 }], 'BGRA', 1, 1), /exceeds/);
});
