import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/quality.dart';

void main() {
  group('ImageFormat', () {
    test('declares png', () {
      expect(ImageFormat.values, const [ImageFormat.png]);
    });
  });

  group('Export', () {
    test('mp4 defaults to Quality.high and carries an explicit quality', () {
      expect(const Export.mp4().quality, Quality.high);
      expect(const Export.mp4(quality: Quality.low).quality, Quality.low);
      expect(const Export.mp4().gifFps, isNull);
      expect(const Export.mp4().imageFormat, isNull);
    });

    test('gif defaults to 15 fps and carries an explicit fps', () {
      expect(const Export.gif().gifFps, 15);
      expect(const Export.gif(fps: 24).gifFps, 24);
      expect(const Export.gif().quality, isNull);
      expect(const Export.gif().imageFormat, isNull);
    });

    test('imageSequence defaults to png', () {
      expect(const Export.imageSequence().imageFormat, ImageFormat.png);
      expect(const Export.imageSequence().quality, isNull);
      expect(const Export.imageSequence().gifFps, isNull);
    });

    test('transparent carries no variant fields', () {
      expect(const Export.transparent().quality, isNull);
      expect(const Export.transparent().gifFps, isNull);
      expect(const Export.transparent().imageFormat, isNull);
    });

    test('mode reports the factory variant', () {
      expect(const Export.mp4().mode, ExportMode.mp4);
      expect(const Export.gif().mode, ExportMode.gif);
      expect(const Export.imageSequence().mode, ExportMode.imageSequence);
      expect(const Export.transparent().mode, ExportMode.transparent);
    });

    test('ExportMode declares the four §24 variants in order', () {
      expect(ExportMode.values, const [
        ExportMode.mp4,
        ExportMode.gif,
        ExportMode.imageSequence,
        ExportMode.transparent,
      ]);
    });

    test('same variant with the same fields is value-equal', () {
      expect(const Export.mp4(quality: Quality.low), const Export.mp4(quality: Quality.low));
      expect(
        const Export.mp4(quality: Quality.low).hashCode,
        const Export.mp4(quality: Quality.low).hashCode,
      );
      expect(const Export.gif(fps: 12), const Export.gif(fps: 12));
      expect(const Export.transparent(), const Export.transparent());
    });

    test('different fields or variants are never equal', () {
      expect(const Export.mp4(), isNot(const Export.mp4(quality: Quality.max)));
      expect(const Export.gif(), isNot(const Export.gif(fps: 12)));
      expect(const Export.mp4(), isNot(const Export.gif()));
      expect(const Export.transparent(), isNot(const Export.mp4()));
      expect(
        const Export.transparent(),
        isNot(const Export.imageSequence()),
      );
    });

    test('toString is stable per variant', () {
      expect(const Export.mp4().toString(), 'Export.mp4(quality: Quality.high)');
      expect(const Export.gif(fps: 12).toString(), 'Export.gif(fps: 12)');
      expect(
        const Export.imageSequence().toString(),
        'Export.imageSequence(format: ImageFormat.png)',
      );
      expect(const Export.transparent().toString(), 'Export.transparent()');
    });
  });
}
