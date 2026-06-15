import 'dart:typed_data';

/// Decoded mono PCM ready for the in-house DSP: the `samples` in `[-1, 1]` and
/// the `sampleRate` they were captured at.
///
/// The gate-default analysis path reads a committed WAV through [readPcmWav]
/// (no ffmpeg) and feeds these samples straight into the FFT / spectral-flux
/// pipeline, so the whole beat-detection chain stays gate-runnable and pure.
typedef PcmAudio = ({Float64List samples, int sampleRate});

/// The in-house minimal PCM-WAV decoder: reads a 16-bit linear-PCM
/// `RIFF`/`WAVE` buffer to a mono [Float64List] in `[-1, 1]`.
///
/// In-house on purpose: a dependency would penalize pana and is overkill for the
/// one shape Fluvie analyses. It parses only what it needs — the `fmt ` and
/// `data` chunks of a canonical PCM file — and downmixes any channel count to
/// mono by averaging. It is pure and deterministic: the same bytes always decode
/// to identical samples, the proof the analysis chain leans on.
///
/// It rejects anything it cannot decode honestly with a [FormatException]: a
/// missing `RIFF`/`WAVE` magic, a non-PCM (`audioFormat != 1`) tag, an
/// unsupported bit depth, or a buffer truncated before the declared `data`
/// length — never silent garbage.
PcmAudio readPcmWav(Uint8List bytes) {
  final view = ByteData.sublistView(bytes);
  if (bytes.length < 44) {
    throw const FormatException('WAV buffer too short to hold a RIFF/WAVE header');
  }
  if (_tag(bytes, 0) != 'RIFF' || _tag(bytes, 8) != 'WAVE') {
    throw const FormatException('Not a RIFF/WAVE file (missing "RIFF"/"WAVE" magic)');
  }
  final fmt = _findChunk(bytes, 'fmt ');
  if (fmt == null) {
    throw const FormatException('WAV file has no "fmt " chunk');
  }
  final audioFormat = view.getUint16(fmt.offset, Endian.little);
  if (audioFormat != 1) {
    throw FormatException('Unsupported WAV audioFormat $audioFormat (only 16-bit PCM = 1)');
  }
  final channels = view.getUint16(fmt.offset + 2, Endian.little);
  final sampleRate = view.getUint32(fmt.offset + 4, Endian.little);
  final bitsPerSample = view.getUint16(fmt.offset + 14, Endian.little);
  if (bitsPerSample != 16) {
    throw FormatException('Unsupported WAV bit depth $bitsPerSample (only 16-bit PCM)');
  }
  if (channels < 1) {
    throw const FormatException('WAV file declares zero channels');
  }
  final data = _findChunk(bytes, 'data');
  if (data == null) {
    throw const FormatException('WAV file has no "data" chunk');
  }
  return _decode16(view, data, channels, sampleRate);
}

/// Decodes the 16-bit PCM [data] chunk to a mono [Float64List], averaging
/// [channels] per frame and normalizing by `32768`.
PcmAudio _decode16(ByteData view, _Chunk data, int channels, int sampleRate) {
  const bytesPerSample = 2;
  final bytesPerFrame = channels * bytesPerSample;
  if (data.offset + data.length > view.lengthInBytes) {
    throw const FormatException('WAV "data" chunk runs past the end of the buffer');
  }
  final frames = data.length ~/ bytesPerFrame;
  final samples = Float64List(frames);
  for (var frame = 0; frame < frames; frame++) {
    final base = data.offset + frame * bytesPerFrame;
    var sum = 0;
    for (var channel = 0; channel < channels; channel++) {
      sum += view.getInt16(base + channel * bytesPerSample, Endian.little);
    }
    samples[frame] = sum / channels / 32768.0;
  }
  return (samples: samples, sampleRate: sampleRate);
}

/// One located RIFF sub-chunk: where its payload starts and how long it is.
typedef _Chunk = ({int offset, int length});

/// Walks the RIFF chunk list from byte 12 and returns the first chunk whose id
/// matches [id], or `null` when none does.
_Chunk? _findChunk(Uint8List bytes, String id) {
  final view = ByteData.sublistView(bytes);
  var cursor = 12;
  while (cursor + 8 <= bytes.length) {
    final chunkId = _tag(bytes, cursor);
    final length = view.getUint32(cursor + 4, Endian.little);
    final payload = cursor + 8;
    if (chunkId == id) return (offset: payload, length: length);
    // Chunks are word-aligned: an odd length carries a pad byte.
    cursor = payload + length + (length.isOdd ? 1 : 0);
  }
  return null;
}

/// The four-character ASCII tag at [offset].
String _tag(Uint8List bytes, int offset) => String.fromCharCodes(bytes.sublist(offset, offset + 4));
