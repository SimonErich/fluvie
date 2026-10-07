import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:meta/meta.dart';

/// A parsed `.cube` 3D LUT: `size` points per axis, red fastest, unit
/// domain in and out.
///
/// A LUT file is external input, so this is a validator first and a parser
/// second: the text is bounded before anything reads it, the size rides
/// honest bounds, every row must be exactly three unit-range numbers, and
/// the table must hold exactly `size³` entries — a truncated file is
/// refused, never padded.
///
/// **The colour-space contract**: input and output are non-linear sRGB in
/// the unit cube, exactly as the frame's bytes already are. The LUT indexes
/// on the frame's encoded values and answers encoded values; no transfer
/// function is applied on either side, and `DOMAIN_MIN`/`DOMAIN_MAX` other
/// than the unit cube are refused rather than rescaled.
@immutable
final class CubeLut {
  const CubeLut._(this.size, this._table);

  /// Parses [text] as a `.cube` file.
  ///
  /// Throws a [FluvieSpecError] for anything outside the contract: text
  /// over [maxBytes], a missing or out-of-bounds `LUT_3D_SIZE`, a domain
  /// other than the unit cube, a malformed row, or a table whose entry
  /// count is not exactly `size³`.
  factory CubeLut.parse(String text, {int maxBytes = 4 << 20}) {
    if (text.length > maxBytes || utf8.encode(text).length > maxBytes) {
      throw FluvieSpecError('LUT file too large', path: ['lut']);
    }
    int? size;
    final values = <double>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final upper = line.toUpperCase();
      if (upper.startsWith('TITLE')) continue;
      if (upper.startsWith('LUT_3D_SIZE')) {
        if (size != null) throw FluvieSpecError('Duplicate LUT_3D_SIZE', path: ['lut']);
        final parsed = int.tryParse(line.substring('LUT_3D_SIZE'.length).trim());
        if (parsed == null || parsed < 2 || parsed > 64) {
          throw FluvieSpecError('LUT_3D_SIZE must be between 2 and 64', path: ['lut']);
        }
        size = parsed;
        continue;
      }
      if (upper.startsWith('DOMAIN_MIN') || upper.startsWith('DOMAIN_MAX')) {
        final wantsZero = upper.startsWith('DOMAIN_MIN');
        final parts = line.split(RegExp(r'\s+')).skip(1).toList();
        final expected = wantsZero ? 0.0 : 1.0;
        if (parts.length != 3 || parts.any((p) => double.tryParse(p) != expected)) {
          throw FluvieSpecError(
            'Only the unit domain is supported: DOMAIN_MIN 0 0 0, DOMAIN_MAX 1 1 1',
            path: ['lut'],
          );
        }
        continue;
      }
      final parts = line.split(RegExp(r'\s+'));
      // Clipped: a malformed row in an external file must not echo whole
      // into an error message.
      final shown = line.length > 40 ? '${line.substring(0, 40)}…' : line;
      if (parts.length != 3) {
        throw FluvieSpecError('A LUT row is three numbers; got "$shown"', path: const ['lut']);
      }
      for (final part in parts) {
        final value = double.tryParse(part);
        if (value == null) {
          throw FluvieSpecError('A LUT row is three numbers; got "$shown"', path: const ['lut']);
        }
        if (!value.isFinite || value < 0 || value > 1) {
          throw FluvieSpecError(
            'LUT value $value is outside the unit domain',
            path: const [
              'lut',
            ],
          );
        }
        values.add(value);
      }
    }
    if (size == null) {
      throw FluvieSpecError('A .cube file needs a LUT_3D_SIZE line', path: ['lut']);
    }
    final expected = size * size * size;
    if (values.length != expected * 3) {
      throw FluvieSpecError(
        'LUT table incomplete: expected $expected entries, found ${values.length ~/ 3}',
        path: const ['lut'],
      );
    }
    return CubeLut._(size, Float64List.fromList(values));
  }

  /// Points per axis.
  final int size;

  final Float64List _table;

  /// The output colour at grid index ([r], [g], [b]), red fastest.
  (double, double, double) rgb(int r, int g, int b) {
    final base = ((b * size + g) * size + r) * 3;
    return (_table[base], _table[base + 1], _table[base + 2]);
  }

  /// Whether every grid point maps exactly to its own coordinate, which is
  /// what lets a caller skip mounting the shader at all.
  bool get isIdentity {
    for (var b = 0; b < size; b++) {
      for (var g = 0; g < size; g++) {
        for (var r = 0; r < size; r++) {
          final (red, green, blue) = rgb(r, g, b);
          if (red != r / (size - 1) || green != g / (size - 1) || blue != b / (size - 1)) {
            return false;
          }
        }
      }
    }
    return true;
  }

  /// The LUT flattened for a 2D sampler: `size` slices of `size`×`size`
  /// tiled horizontally (blue selects the tile), 8-bit RGBA, opaque.
  Uint8List toRgbaBytes() {
    final bytes = Uint8List(size * size * size * 4);
    for (var b = 0; b < size; b++) {
      for (var g = 0; g < size; g++) {
        for (var r = 0; r < size; r++) {
          final (red, green, blue) = rgb(r, g, b);
          final pixel = (g * size * size + b * size + r) * 4;
          bytes[pixel] = (red * 255).round();
          bytes[pixel + 1] = (green * 255).round();
          bytes[pixel + 2] = (blue * 255).round();
          bytes[pixel + 3] = 255;
        }
      }
    }
    return bytes;
  }

  @override
  String toString() => 'CubeLut(${size}x$size×$size)';
}
