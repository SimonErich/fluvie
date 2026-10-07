import 'dart:typed_data';

/// Read-only scope counts from a settled, encoded sRGB RGBA preview.
final class ScopeData {
  /// Computes scopes without mutating the image or the editor document.
  factory ScopeData.fromRgba(Uint8List rgba, int width, int height) {
    if (width <= 0 || height <= 0 || rgba.length != width * height * 4) {
      throw ArgumentError('RGBA dimensions must match the input bytes');
    }
    final r = List<int>.filled(256, 0);
    final g = List<int>.filled(256, 0);
    final b = List<int>.filled(256, 0);
    final l = List<int>.filled(256, 0);
    final wave = List<int>.filled(4096, 0);
    final vector = List<int>.filled(4096, 0);
    var samples = 0;
    for (var pixel = 0; pixel < width * height; pixel++) {
      final offset = pixel * 4;
      if (rgba[offset + 3] == 0) continue;
      final red = rgba[offset];
      final green = rgba[offset + 1];
      final blue = rgba[offset + 2];
      final y = 0.2126 * red + 0.7152 * green + 0.0722 * blue;
      r[red]++;
      g[green]++;
      b[blue]++;
      l[y.round().clamp(0, 255)]++;
      final xBin = ((pixel % width) * 64 ~/ width).clamp(0, 63);
      wave[(y * 63 / 255).round().clamp(0, 63) * 64 + xBin]++;
      final cb = ((blue - y) / (2 * (1 - 0.0722)) / 255 + 0.5).clamp(0.0, 1.0);
      final cr = ((red - y) / (2 * (1 - 0.2126)) / 255 + 0.5).clamp(0.0, 1.0);
      vector[(cr * 63).round() * 64 + (cb * 63).round()]++;
      samples++;
    }
    return ScopeData._(r, g, b, l, wave, vector, samples);
  }
  ScopeData._(
    this.red,
    this.green,
    this.blue,
    this.luma,
    this.waveform,
    this.vectorscope,
    this.samples,
  );

  /// Counts per encoded red level (0–255).
  final List<int> red;

  /// Counts per encoded green level (0–255).
  final List<int> green;

  /// Counts per encoded blue level (0–255).
  final List<int> blue;

  /// Counts per Rec. 709-weighted encoded luminance level.
  final List<int> luma;

  /// 64 horizontal bins × 64 luminance bins, row-major from black upward.
  final List<int> waveform;

  /// 64×64 Cb/Cr density bins, centred on neutral chroma.
  final List<int> vectorscope;

  /// Number of nontransparent pixels sampled.
  final int samples;
}
