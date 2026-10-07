import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { publishedProof, publishedRenderProof, verifyPublishedProof } from './rendered_example.mjs';

const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');
const source = Buffer.from('Video build() => video;');
const video = Buffer.from('encoded video fixture');
const poster = Buffer.from('captured poster fixture');
const receipt = {
  sourceFingerprint: 'input-fingerprint',
  inputs: { files: [{ path: 'input:/project/promo.dart', sha256: hash(source), byteLength: source.length }] },
  output: { path: '/project/promo.mp4', sha256: hash(video), byteLength: video.length,
    media: { width: 320, height: 320, declaredFrameCount: 120, averageFrameRate: '12/1', durationSeconds: 10 } },
  poster: { path: '/project/promo.poster.png', sha256: hash(poster), byteLength: poster.length },
  capture: { width: 320, height: 320, fps: 12, frameCount: 120, ffmpegArgs: ['-an', 'out.mp4'] },
  toolchain: { ffmpegVersion: 'verified FFmpeg', sdk: { flutter: { frameworkVersion: 'test' } } },
};

test('published proof preserves genuine capture facts without local paths or full package inventory', () => {
  const proof = publishedProof(receipt, source, video, poster);
  verifyPublishedProof(proof, source, video, poster);
  assert.equal(proof.output.media.declaredFrameCount, 120);
  assert.equal(proof.source.sha256, hash(source));
  assert.equal(proof.output.path, 'promo.mp4');
  assert.doesNotMatch(JSON.stringify(proof), /\/project\//);
  assert.equal(proof.inputs, undefined);
});

test('modified source, video or poster requires regeneration before publishing', () => {
  const proof = publishedProof(receipt, source, video, poster);
  for (const buffers of [[Buffer.from('changed'), video, poster], [source, Buffer.from('changed'), poster], [source, video, Buffer.from('changed')]]) {
    assert.throws(() => verifyPublishedProof(proof, ...buffers), /hash|identity/);
  }
  const wrong = structuredClone(receipt);
  wrong.output.media.declaredFrameCount = 119;
  assert.throws(() => publishedProof(wrong, source, video, poster), /frame count/);
});

test('a named authoring export verifies without a poster and rejects malformed FPS', () => {
  const recorded = structuredClone(receipt);
  recorded.inputs.files[0].path = 'input:/project/intro.dart';
  const proof = publishedRenderProof(recorded, source, video,
    { sourcePath: 'cat.dart', inputPath: 'intro.dart', outputPath: 'cat.mp4' });
  assert.equal(proof.source.path, 'cat.dart');
  assert.equal(proof.poster, undefined);
  verifyPublishedProof(proof, source, video);
  assert.throws(() => verifyPublishedProof(proof, Buffer.from('edited'), video), /hash/);
  for (const rate of ['not-a-rate', '30/0', '0/1']) {
    const malformed = structuredClone(recorded);
    malformed.output.media.averageFrameRate = rate;
    assert.throws(() => publishedRenderProof(malformed, source, video,
      { inputPath: 'intro.dart' }), /FPS/);
  }
});
