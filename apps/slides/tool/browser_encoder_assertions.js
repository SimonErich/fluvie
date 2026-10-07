// Shared real-browser acceptance. Evaluated as an async expression.
(async () => {
  for (let i = 0; i < 300 && !globalThis.FluvieFfmpeg; i++) await new Promise(r => setTimeout(r, 50));
  const ff = globalThis.FluvieFfmpeg;
  if (!ff || !ff.terminate || !ff.deleteFile) throw Error('Missing shipped lifecycle bridge');
  const ActualDecoder = globalThis.VideoDecoder;
  const getImageData = OffscreenCanvasRenderingContext2D.prototype.getImageData;
  try {
  await ff.load();
  const decoder = globalThis.FluvieClipDecoder;
  if (!decoder) throw Error('Missing shipped clip decoder');
  const fixture = new Uint8Array(await (await fetch('/_fixture.mp4')).arrayBuffer());
  const metadata = await decoder.probe(fixture);
  if (metadata.width !== 320 || metadata.height !== 240 || metadata.frameCount !== 30 || Math.abs(metadata.fps - 30) > 0.01 || metadata.hasAudio !== false) throw Error('Incorrect fixture metadata: ' + JSON.stringify(metadata));
  let copiedFrames = 0;
  const decodedColors = [];
  let observedColors = decodedColors;
  let captureNative = false, nativeOrdinal = 0;
  const nativeCopies = [];
  globalThis.VideoDecoder = class extends ActualDecoder {
    constructor(options) { super({...options, output: frame => {
      if (!observedColors.length) observedColors.push(frame.colorSpace.toJSON());
      if (captureNative) {
        const index = nativeOrdinal++;
        if ([0, 15, 29].includes(index)) {
          const clone = frame.clone();
          const raw = new Uint8Array(clone.allocationSize());
          nativeCopies.push(clone.copyTo(raw).then(layout => ({
            index, format: clone.format, timestamp: clone.timestamp,
            bytes: ['I420', 'NV12'].includes(clone.format)
              ? FluvieBrowserPixelOracle.packI420(raw, layout, clone.format, 512, 256)
              : FluvieBrowserPixelOracle.packRgba(raw, layout, clone.format, 512, 256),
          })).finally(() => clone.close()));
        }
      }
      options.output(frame);
    }}); }
  };
  OffscreenCanvasRenderingContext2D.prototype.getImageData = function(...args) { copiedFrames++; return getImageData.apply(this, args); };
  const indices = [0, 15, 29, 15];
  const rgba = await decoder.extractFrames(fixture, indices, 80, 60);
  OffscreenCanvasRenderingContext2D.prototype.getImageData = getImageData;
  if (rgba.length !== 4 || rgba.some(frame => frame.length !== 80 * 60 * 4) || copiedFrames !== 3 || rgba[1] !== rgba[3]) throw Error('Requested-frame RGBA retention is not bounded');
  if (!rgba.every(frame => frame.some(value => value !== 0))) throw Error('Decoded fixture is blank');
  let refused = false;
  try { await decoder.probe(new Uint8Array([1, 2, 3, 4, 5])); } catch (error) { refused = String(error).includes('MP4/MOV'); }
  if (!refused) throw Error('Unsupported video container was not refused clearly');
  let oversized = false;
  try { await decoder.extractFrames(fixture, [0, 1], 16384, 16384); } catch (error) { oversized = String(error).includes('128 MiB'); }
  if (!oversized) throw Error('Unbounded RGBA allocation was not refused');
  await ff.writeFile('fixture.mp4', fixture.slice());
  const fullRgba = await decoder.extractFrames(fixture, [0, 15, 29], 320, 240);
  globalThis.__fluviePixelDiagnostic = fullRgba[0];
  // This untagged SD fixture legitimately gets different default matrices:
  // Chrome/Firefox choose BT.709, WebKit chooses SMPTE170M. Validate pixel
  // conversion against the matrix the decoder actually reports. Chroma
  // reconstruction differs across engines: compare dense RGB area means and
  // full-resolution flat pixels at the same <=3 RMS, then require byte-exact
  // native YUV separately. Tagged-source metadata is checked below as well.
  const color = decodedColors[0];
  const matrix = { bt709: 'bt709', smpte170m: 'bt601', bt470bg: 'bt601' }[color.matrix];
  if (!matrix || typeof color.fullRange !== 'boolean') throw Error('Unknown fixture color space: ' + JSON.stringify(color));
  const rawExit = await ff.exec(['-y', '-i', 'fixture.mp4', '-vf',
    "select='eq(n,0)+eq(n,15)+eq(n,29)'", '-vsync', '0', '-pix_fmt', 'yuv420p', '-f', 'rawvideo', 'reference.yuv']);
  if (rawExit !== 0) throw Error('Reference clip decode failed');
  const reference = await ff.readFile('reference.yuv');
  const frameBytes = 320 * 240 * 3 / 2;
  if (reference.length !== 3 * frameBytes) throw Error('Unexpected reference frame count');
  const decodePixels = [0, 1, 2].map(frame => FluvieBrowserPixelOracle.assertPixels(
    fullRgba[frame], FluvieBrowserPixelOracle.referenceRgb(
      reference.subarray(frame * frameBytes, (frame + 1) * frameBytes), 320, 240, matrix, color.fullRange),
    320, 240, `Untagged source frame ${[0, 15, 29][frame]}`,
  ));
  await ff.deleteFile('reference.yuv');
  // Write BT.709 into both the H.264 VUI and MP4 container without changing
  // the picture samples. Every engine must now agree with one fixed reference.
  const taggedExit = await ff.exec(['-y', '-i', 'fixture.mp4', '-c:v', 'copy', '-bsf:v',
    'h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1',
    '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709', 'tagged.mp4']);
  if (taggedExit !== 0) throw Error('Unable to tag color fixture');
  const taggedColors = [];
  observedColors = taggedColors;
  const taggedFrames = await decoder.extractFrames(await ff.readFile('tagged.mp4'), [0, 15, 29], 320, 240);
  const taggedReferenceExit = await ff.exec(['-y', '-i', 'tagged.mp4', '-vf',
    "select='eq(n,0)+eq(n,15)+eq(n,29)'",
    '-vsync', '0', '-pix_fmt', 'yuv420p', '-f', 'rawvideo', 'tagged.yuv']);
  if (taggedReferenceExit !== 0) throw Error('Tagged reference decode failed');
  const taggedReference = await ff.readFile('tagged.yuv');
  if (taggedReference.length !== 3 * frameBytes) throw Error('Unexpected tagged reference frame count');
  if (taggedColors[0]?.matrix !== 'bt709' || taggedColors[0]?.fullRange !== false) {
    throw Error('Tagged source color metadata changed: ' + JSON.stringify(taggedColors));
  }
  const taggedPixels = [0, 1, 2].map(frame => FluvieBrowserPixelOracle.assertPixels(
    taggedFrames[frame], FluvieBrowserPixelOracle.referenceRgb(
      taggedReference.subarray(frame * frameBytes, (frame + 1) * frameBytes), 320, 240, 'bt709', false),
    320, 240, `Tagged BT.709 source frame ${[0, 15, 29][frame]}`,
  ));
  await ff.deleteFile('tagged.mp4'); await ff.deleteFile('tagged.yuv');
  // WebKit/GStreamer copyTo currently truncates padded NV12 source planes
  // for this 320px fixture. A 512px stride-aligned fixture exercises complete
  // native copies on every engine, without changing the production decoder or
  // tolerating missing bytes. Compare against its independent FFmpeg decode.
  const nativeExit = await ff.exec(['-y', '-i', 'fixture.mp4', '-vf', 'pad=512:256',
    '-c:v', 'libx264', '-crf', '18', '-preset', 'medium', '-profile:v', 'high',
    '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709', 'native.mp4']);
  if (nativeExit !== 0) throw Error('Unable to produce aligned native-plane fixture');
  const nativeReferenceExit = await ff.exec(['-y', '-i', 'native.mp4', '-vf',
    "select='eq(n,0)+eq(n,15)+eq(n,29)'", '-vsync', '0', '-pix_fmt', 'yuv420p', '-f', 'rawvideo', 'native.yuv']);
  if (nativeReferenceExit !== 0) throw Error('Independent native-plane decode failed');
  const nativeReference = await ff.readFile('native.yuv');
  captureNative = true;
  await decoder.extractFrames(await ff.readFile('native.mp4'), [0, 15, 29], 512, 256);
  captureNative = false;
  const nativeFrames = await Promise.all(nativeCopies);
  const nativeFrameBytes = 512 * 256 * 3 / 2;
  if (nativeFrames.length !== 3 || nativeReference.length !== 3 * nativeFrameBytes) throw Error('Missing native reference frames');
  let nativeRgbReference;
  if (nativeFrames.some(frame => !['I420', 'NV12'].includes(frame.format))) {
    // Some engines expose already-converted RGB VideoFrames. Keep the strict
    // full-resolution RGB oracle for that representation; do not claim YUV
    // sample identity when the browser does not expose YUV planes.
    const nativeRgbExit = await ff.exec(['-y', '-i', 'native.mp4', '-vf',
      "select='eq(n,0)+eq(n,15)+eq(n,29)',scale=in_color_matrix=bt709:in_range=tv:out_range=pc",
      '-vsync', '0', '-pix_fmt', 'rgba', '-f', 'rawvideo', 'native.rgba']);
    if (nativeRgbExit !== 0) throw Error('Independent native RGB decode failed');
    nativeRgbReference = await ff.readFile('native.rgba');
    if (nativeRgbReference.length !== 3 * 512 * 256 * 4) throw Error('Missing native RGB reference frames');
    await ff.deleteFile('native.rgba');
  }
  const nativePlanes = nativeFrames.map((frame, i) => {
    const result = {index: frame.index, format: frame.format, timestamp: frame.timestamp};
    if (['I420', 'NV12'].includes(frame.format)) return {
      ...result, comparison: 'byte-exact YUV',
      ...FluvieBrowserPixelOracle.assertNative(frame.bytes,
        nativeReference.subarray(i * nativeFrameBytes, (i + 1) * nativeFrameBytes), `Native source frame ${frame.index}`),
    };
    const bytes = 512 * 256 * 4;
    const pixels = FluvieBrowserPixelOracle.assertPixels(frame.bytes,
      nativeRgbReference.subarray(i * bytes, (i + 1) * bytes), 512, 256, `Native RGB frame ${frame.index}`);
    if (pixels.fullRgbaRms > 3) throw Error(`Native RGB frame ${frame.index} full-resolution RMS exceeds 3: ${pixels.fullRgbaRms}`);
    return {...result, comparison: 'full-resolution RGB RMS <=3', ...pixels};
  });
  await ff.deleteFile('native.mp4'); await ff.deleteFile('native.yuv');
  const audioExit = await ff.exec(['-y', '-i', 'fixture.mp4', '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1', '-c:v', 'copy', '-c:a', 'aac', '-shortest', 'audio.mp4']);
  if (audioExit !== 0) throw Error('Unable to produce embedded audio fixture');
  const withAudio = await decoder.probe(await ff.readFile('audio.mp4'));
  if (withAudio.hasAudio !== true) throw Error('Embedded audio was dropped by probe metadata');
  await ff.deleteFile('fixture.mp4'); await ff.deleteFile('audio.mp4');
  async function encode() {
    const bytes = new Uint8Array(64 * 64 * 4 * 10);
    for (let i = 0; i < bytes.length; i += 4) { bytes[i] = (i >> 8) & 255; bytes[i + 3] = 255; }
    await ff.writeFile('frames.rgba', bytes);
    const exit = await ff.exec(['-y', '-f', 'rawvideo', '-pixel_format', 'rgba', '-video_size', '64x64',
      '-framerate', '30', '-i', 'frames.rgba', '-c:v', 'libx264', '-crf', '21', '-preset', 'ultrafast',
      '-pix_fmt', 'yuv420p', '-an', 'out.mp4']);
    if (exit !== 0) throw Error('Actual H264 encode failed: ' + exit);
    const output = await ff.readFile('out.mp4');
    if (output.length < 100 || String.fromCharCode(...output.slice(4, 8)) !== 'ftyp') throw Error('Not an MP4');
    await ff.deleteFile('frames.rgba'); await ff.deleteFile('out.mp4');
    let absent = false;
    try { await ff.readFile('out.mp4'); } catch (_) { absent = true; }
    if (!absent) throw Error('deleteFile left an output in VFS');
    return output.length;
  }
  const firstBytes = await encode();
  const longJob = ff.exec(['-y', '-f', 'lavfi', '-i', 'testsrc=size=640x360:rate=30', '-t', '3600',
    '-c:v', 'libx264', '-preset', 'slow', '-pix_fmt', 'yuv420p', 'cancel.mp4']).then(
      () => 'completed', () => 'cancelled');
  await new Promise(r => setTimeout(r, 50));
  await ff.terminate();
  if (await longJob !== 'cancelled') throw Error('Worker did not reject cancelled encode');
  await ff.load();
  const reloadedBytes = await encode();
  return {firstBytes, reloadedBytes, cancelled: true, cleanup: true, clipFrames: indices, retainedRgbaFrames: copiedFrames, decodePixels, decodedColors, taggedPixels, taggedColors, nativePlanes, clipWidth: metadata.width, hasEmbeddedAudio: withAudio.hasAudio, rejectsUnsupportedContainer: refused};
  } finally {
    globalThis.VideoDecoder = ActualDecoder;
    OffscreenCanvasRenderingContext2D.prototype.getImageData = getImageData;
    await ff.terminate();
  }
})()
