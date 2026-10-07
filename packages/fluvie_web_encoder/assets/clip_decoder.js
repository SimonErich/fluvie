// Fluvie's browser clip decoder. Load this package asset as a module before
// rendering or previewing clips. The host vendors mp4box.js at
// vendor/mp4box/mp4box.all.min.js relative to document.baseURI.
// probe() returns audio presence as well as video metadata so every render and
// live preview can include a clip's embedded sound.
let mp4boxLoading = null;
const loadMp4box = () => (mp4boxLoading ??= new Promise((ok, fail) => {
  if (globalThis.MP4Box) return ok();
  const s = document.createElement('script');
  s.src = new URL('vendor/mp4box/mp4box.all.min.js', document.baseURI).href;
  s.onload = () => (globalThis.MP4Box ? ok() : fail(new Error('mp4box.js: no MP4Box global')));
  s.onerror = () => fail(new Error('failed to load vendor/mp4box/mp4box.all.min.js'));
  document.head.appendChild(s);
}));

// Demux every video sample plus the track info from the clip bytes.
async function demux(bytes) {
  if (!(bytes instanceof Uint8Array) || bytes.length < 12 ||
      String.fromCharCode(...bytes.slice(4, 8)) !== 'ftyp') {
    throw new Error('Browser clip preview supports MP4/MOV (ISO BMFF); this source needs conversion.');
  }
  await loadMp4box();
  return new Promise((resolve, reject) => {
    const file = MP4Box.createFile();
    const samples = [];
    let track = null;
    let hasAudio = false;
    const timer = setTimeout(() => reject(new Error('Timed out demuxing MP4 video samples')), 10000);
    file.onError = (e) => { clearTimeout(timer); reject(new Error('mp4box demux: ' + e)); };
    file.onReady = (info) => {
      hasAudio = !!(info.audioTracks && info.audioTracks.length);
      track = info.videoTracks && info.videoTracks[0];
      if (!track || !track.nb_samples) { clearTimeout(timer); return reject(new Error('clip has no video track')); }
      file.setExtractionOptions(track.id, null, { nbSamples: track.nb_samples });
      file.start();
    };
    file.onSamples = (id, user, list) => {
      for (const s of list) samples.push(s);
      if (track && samples.length >= track.nb_samples) { clearTimeout(timer); resolve({ file, track, samples, hasAudio }); }
    };
    const ab = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
    ab.fileStart = 0;
    file.appendBuffer(ab);
    file.flush();
  });
}

// The avcC/hvcC/... record a VideoDecoder needs for length-prefixed samples.
function description(file, track) {
  const trak = file.getTrackById(track.id);
  for (const entry of trak.mdia.minf.stbl.stsd.entries) {
    const box = entry.avcC || entry.hvcC || entry.vpcC || entry.av1C;
    if (!box) continue;
    // mp4box.js exposes DataStream as its own global, not a MP4Box property.
    const ds = new DataStream(undefined, 0, DataStream.BIG_ENDIAN);
    box.write(ds);
    return new Uint8Array(ds.buffer, 8); // strip the 8-byte box header
  }
  return undefined;
}

async function probe(bytes) {
  const { track, hasAudio } = await demux(bytes);
  const seconds = track.duration > 0 ? track.duration / track.timescale : track.movie_duration / track.movie_timescale;
  const frameCount = track.nb_samples;
  return {
    fps: seconds > 0 ? frameCount / seconds : 30,
    frameCount,
    hasAudio,
    width: track.video ? track.video.width : track.track_width,
    height: track.video ? track.video.height : track.track_height,
  };
}

async function extractFrames(bytes, indices, width, height) {
  if (!indices.length) return [];
  if (!Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1 ||
      indices.some(i => !Number.isInteger(i)) || width * height * 4 * new Set(indices).size > 128 * 1024 * 1024) {
    throw new Error('Requested clip RGBA batch must use positive dimensions and fit within 128 MiB.');
  }
  if (!globalThis.VideoDecoder || !globalThis.OffscreenCanvas) throw new Error('This browser does not support WebCodecs clip decoding.');
  const { file, track, samples } = await demux(bytes);
  const config = {
    codec: track.codec,
    description: description(file, track),
    // Preserve the dimensions known from the container for capability probes.
    codedWidth: track.video ? track.video.width : track.track_width,
    codedHeight: track.video ? track.video.height : track.track_height,
  };
  if (!(await VideoDecoder.isConfigSupported(config)).supported) throw new Error('Unsupported browser video codec: ' + track.codec);
  const canvas = new OffscreenCanvas(width, height);
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) throw new Error('Browser could not allocate the clip canvas');
  const frames = new Map();
  const presentation = [...samples].sort((a, b) => a.cts - b.cts);
  const requested = new Map(indices.map(i => {
    const index = Math.max(0, Math.min(presentation.length - 1, i));
    return [Math.round(1e6 * presentation[index].cts / track.timescale), index];
  }));
  let failure;
  const decoder = new VideoDecoder({
    output: frame => {
      try {
        const index = requested.get(frame.timestamp);
        if (index !== undefined && !frames.has(index)) {
          ctx.drawImage(frame, 0, 0, width, height);
          frames.set(index, new Uint8Array(ctx.getImageData(0, 0, width, height).data));
        }
      } catch (error) { failure = error; }
      finally { frame.close(); }
    },
    error: error => { failure = error; },
  });
  try {
    decoder.configure(config);
    for (const sample of samples) {
      if (failure) throw failure;
      decoder.decode(new EncodedVideoChunk({
        type: sample.is_sync ? 'key' : 'delta',
        timestamp: Math.round(1e6 * sample.cts / track.timescale),
        duration: Math.round(1e6 * sample.duration / track.timescale), data: sample.data,
      }));
      // Keep compressed decode work bounded as well as retained RGBA. Yielding
      // lets WebCodecs drain frames without flushing between dependent samples.
      while (decoder.decodeQueueSize > 32 && !failure) await new Promise(r => setTimeout(r, 0));
    }
    if (failure) throw failure;
    await decoder.flush();
    if (failure) throw failure;
  } finally {
    if (decoder.state !== 'closed') decoder.close();
  }
  return indices.map(i => {
    const frame = frames.get(Math.max(0, Math.min(presentation.length - 1, i)));
    if (!frame) throw new Error('Decoder did not produce source frame ' + i);
    return frame;
  });
}

globalThis.FluvieClipDecoder = { probe, extractFrames };
