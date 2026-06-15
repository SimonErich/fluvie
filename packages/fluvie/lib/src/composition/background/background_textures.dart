part of 'background.dart';

/// `Background.noise`: a deterministic grayscale value-noise texture.
final class _NoiseTexture extends _BackgroundSpec {
  const _NoiseTexture(this.scale) : assert(scale > 0, 'noise scale must be > 0');

  final double scale;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _NoisePainter(scale: scale));
}

/// Cell-value noise from one seeded sequence: dark base, one
/// gray cell per `4·scale` px square, cell values drawn row-major from a
/// fixed-seed [math.Random] — bytes are identical pump to pump and machine
/// to machine.
final class _NoisePainter extends CustomPainter {
  const _NoisePainter({required this.scale});

  final double scale;

  /// The fixed literal seed of every Fluvie texture (determinism contract:
  /// seeded randomness only, and one seed so identical input means identical
  /// frames).
  static const int _seed = 0x466C7576; // 'Fluv'

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF101010));
    final cell = 4.0 * scale;
    final columns = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    final random = math.Random(_seed);
    final paint = Paint();
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final gray = 16 + (random.nextDouble() * 64).round();
        paint.color = Color.fromARGB(0xFF, gray, gray, gray);
        canvas.drawRect(Rect.fromLTWH(column * cell, row * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_NoisePainter oldDelegate) => oldDelegate.scale != scale;
}

/// `Background.vhs`: a deterministic VHS-style texture.
final class _VhsTexture extends _BackgroundSpec {
  const _VhsTexture();

  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _VhsPainter());
}

/// Scanlines over static bands: a dark tape base, three pale
/// horizontal bands placed by a fixed-seed [math.Random], and a one-pixel
/// scanline every four pixels on top — fully deterministic, no clocks.
final class _VhsPainter extends CustomPainter {
  const _VhsPainter();

  /// The same fixed-seed policy as [_NoisePainter._seed], offset so the two
  /// textures never share a sequence.
  static const int _seed = 0x466C7576 + 1;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF14121A));
    final random = math.Random(_seed);
    final band = Paint()..color = const Color(0x14FFFFFF);
    for (var i = 0; i < 3; i++) {
      final top = random.nextDouble() * size.height;
      final height = 8 + random.nextDouble() * 24;
      canvas.drawRect(Rect.fromLTWH(0, top, size.width, height), band);
    }
    final scanline = Paint()..color = const Color(0x59000000);
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scanline);
    }
  }

  @override
  bool shouldRepaint(_VhsPainter oldDelegate) => false;
}
