import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

const source = await readFile(new URL('../../apps/slides/tool/browser_encoder_assertions.js', import.meta.url), 'utf8');

// Fault injection checks the test harness's cleanup only. Browser acceptance
// still executes the shipped bridges and real decoders in each selected engine.
for (const stage of ['load', 'extractFrames']) {
  test(`assertion failure during ${stage} restores instrumentation and terminates the worker`, async () => {
    const OriginalDecoder = class {};
    const originalGetImageData = () => {};
    const Context = class {};
    Context.prototype.getImageData = originalGetImageData;
    let terminated = 0;
    const context = {
      VideoDecoder: OriginalDecoder,
      OffscreenCanvasRenderingContext2D: Context,
      FluvieFfmpeg: {
        load: async () => { if (stage === 'load') throw Error('injected failure'); },
        terminate: async () => { terminated++; },
        deleteFile: async () => {},
      },
      FluvieClipDecoder: {
        probe: async () => ({ width: 320, height: 240, frameCount: 30, fps: 30, hasAudio: false }),
        extractFrames: async () => { throw Error('injected failure'); },
      },
      fetch: async () => ({ arrayBuffer: async () => new ArrayBuffer(8) }),
    };
    await assert.rejects(runInNewContext(source, context), /injected failure/);
    assert.equal(context.VideoDecoder, OriginalDecoder);
    assert.equal(Context.prototype.getImageData, originalGetImageData);
    assert.equal(terminated, 1);
  });
}
