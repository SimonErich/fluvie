import { createHash } from 'node:crypto';

function identity(path, bytes) {
  return { path, byteLength: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex') };
}

// Publish measured capture facts, not local sandbox or dependency inventory paths.
export function publishedRenderProof(receipt, source, video,
  { sourcePath = 'promo.dart', outputPath = 'promo.mp4', inputPath = sourcePath } = {}) {
  const sourceIdentity = identity(sourcePath, source);
  const input = receipt.inputs.files.find((file) => file.path.endsWith(`/${inputPath}`));
  if (input?.sha256 !== sourceIdentity.sha256) throw new Error('Rendered source hash is stale');
  const proof = {
    schemaVersion: 1,
    source: sourceIdentity,
    sourceFingerprint: receipt.sourceFingerprint,
    output: { path: outputPath, byteLength: receipt.output.byteLength,
      sha256: receipt.output.sha256, media: receipt.output.media },
    capture: receipt.capture,
    reproduction: {
      command: `fluvie render ${sourcePath} --out ${outputPath} --no-cache`,
      flutter: receipt.toolchain.sdk.flutter.frameworkVersion,
      engineRevision: receipt.toolchain.sdk.flutter.engineRevision,
      dart: receipt.toolchain.sdk.flutter.dartSdkVersion,
      ffmpeg: receipt.toolchain.ffmpegVersion,
      note: 'Resource and timing replay is supported. Encoded bytes can vary across engines and platforms.',
    },
  };
  verifyPublishedProof(proof, source, video);
  return proof;
}

export function publishedProof(receipt, source, video, poster) {
  const proof = publishedRenderProof(receipt, source, video);
  proof.poster = { path: 'promo.poster.png', byteLength: receipt.poster.byteLength, sha256: receipt.poster.sha256 };
  verifyPublishedProof(proof, source, video, poster);
  return proof;
}

export function verifyPublishedProof(proof, source, video, poster) {
  if (proof.schemaVersion !== 1) throw new Error('Unsupported rendered proof schemaVersion');
  for (const [field, bytes] of [['source', source], ['output', video], ...(proof.poster ? [['poster', poster]] : [])]) {
    const actual = identity(proof[field].path, bytes);
    if (actual.sha256 !== proof[field].sha256 || actual.byteLength !== proof[field].byteLength) {
      throw new Error(`Published ${field} hash/identity is stale; regenerate the example`);
    }
  }
  const { capture, output: { media } } = proof;
  if (capture.width !== media.width || capture.height !== media.height) throw new Error('Capture canvas differs from encoded media');
  if (capture.frameCount !== media.declaredFrameCount) throw new Error('Encoded frame count differs from capture');
  const [numerator, denominator] = String(media.averageFrameRate).split('/').map(Number);
  const fps = numerator / denominator;
  if (!Number.isFinite(fps) || fps <= 0 || !Number.isFinite(capture.fps) || capture.fps <= 0 ||
      Math.abs(fps - capture.fps) > 0.001) throw new Error('Encoded FPS differs from capture');
  if (Math.abs(media.durationSeconds - capture.frameCount / capture.fps) > 0.01) throw new Error('Encoded duration differs from capture');
}
