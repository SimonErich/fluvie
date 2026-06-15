import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/rendering/render_config.dart';

void main() {
  RenderConfig demo() => RenderConfig(width: 320, height: 240, frameCount: 48);

  group('RenderConfig', () {
    test('applies the documented defaults', () {
      final config = demo();
      expect(config.fps, 30);
      expect(config.startFrame, 0);
      expect(config.quality, Quality.high);
      expect(config.cacheEnabled, isTrue);
    });

    test('an odd width throws ArgumentError', () {
      expect(() => RenderConfig(width: 321, height: 240, frameCount: 48), throwsArgumentError);
    });

    test('an odd height throws ArgumentError', () {
      expect(() => RenderConfig(width: 320, height: 241, frameCount: 48), throwsArgumentError);
    });

    test('non-positive dimensions throw ArgumentError', () {
      expect(() => RenderConfig(width: 0, height: 240, frameCount: 48), throwsArgumentError);
      expect(() => RenderConfig(width: 320, height: -2, frameCount: 48), throwsArgumentError);
    });

    test('a zero fps throws ArgumentError', () {
      expect(
        () => RenderConfig(width: 320, height: 240, frameCount: 48, fps: 0),
        throwsArgumentError,
      );
    });

    test('a zero frameCount throws ArgumentError', () {
      expect(() => RenderConfig(width: 320, height: 240, frameCount: 0), throwsArgumentError);
    });

    test('a negative startFrame throws ArgumentError', () {
      expect(
        () => RenderConfig(width: 320, height: 240, frameCount: 48, startFrame: -1),
        throwsArgumentError,
      );
    });

    test('json round-trips including the quality name', () {
      final config = RenderConfig(
        width: 640,
        height: 360,
        fps: 24,
        frameCount: 120,
        startFrame: 12,
        quality: Quality.max,
        cacheEnabled: false,
      );

      final json = config.toJson();

      expect(json['quality'], 'max');
      expect(RenderConfig.fromJson(json), config);
    });

    test('value equality and hashCode', () {
      expect(demo(), demo());
      expect(demo().hashCode, demo().hashCode);
      expect(demo(), isNot(equals(demo().copyWith(fps: 60))));
    });

    test('copyWith replaces exactly the given fields', () {
      final config = demo().copyWith(quality: Quality.low, startFrame: 6);

      expect(config.quality, Quality.low);
      expect(config.startFrame, 6);
      expect(config.width, 320);
      expect(config.height, 240);
      expect(config.frameCount, 48);
    });

    test('copyWith re-validates', () {
      expect(() => demo().copyWith(width: 7), throwsArgumentError);
    });

    test('toString names the window and quality', () {
      expect(demo().toString(), contains('320x240@30'));
      expect(demo().toString(), contains('0..47'));
    });
  });
}
