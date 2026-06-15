import 'package:flutter/painting.dart' show Alignment, Color, FontWeight, TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/serialization/codecs/defaults_codec.dart';
import 'package:fluvie/src/serialization/codecs/export_codec.dart';
import 'package:fluvie/src/serialization/codecs/keyframe_codec.dart';
import 'package:fluvie/src/serialization/codecs/motion_codec.dart';
import 'package:fluvie/src/serialization/codecs/text_style_codec.dart';
import 'package:fluvie/src/serialization/codecs/transition_codec.dart';
import 'package:fluvie/src/serialization/codecs/video_size_codec.dart';

void main() {
  group('transition codec', () {
    test('round-trips every kind', () {
      for (final transition in <Transition>[
        const Transition.cut(),
        const Transition.crossFade(Time.seconds(0.5)),
        const Transition.wipe(Time.frames(12), direction: Edge.left),
        const Transition.zoom(Time.frames(10), into: Alignment.topRight),
        const Transition.slide(Time.frames(8), from: Edge.left),
      ]) {
        expect(decodeTransition(encodeTransition(transition)), transition);
      }
    });

    test('applies defaults for absent fields', () {
      final wipe = decodeTransition(const {'kind': 'wipe', 'duration': '10f'});
      expect(wipe, const Transition.wipe(Time.frames(10)));
      final zoom = decodeTransition(const {'kind': 'zoom', 'duration': '10f', 'ease': 'snappy'});
      expect(zoom.ease, Ease.snappy);
    });

    test('rejects bad input', () {
      expect(() => decodeTransition('cut'), throwsA(isA<FluvieSpecError>()));
      expect(
        () => decodeTransition(const {'kind': 'crossFade'}),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('export codec', () {
    test('round-trips every mode', () {
      for (final export in <Export>[
        const Export.mp4(),
        const Export.mp4(quality: Quality.low),
        const Export.gif(fps: 12),
        const Export.imageSequence(),
        const Export.transparent(),
      ]) {
        expect(decodeExport(encodeExport(export)), export);
      }
    });

    test('applies defaults and rejects bad input', () {
      expect(decodeExport(const {'mode': 'mp4'}), const Export.mp4());
      expect(decodeExport(const {'mode': 'gif'}), const Export.gif());
      expect(decodeExport(const {'mode': 'imageSequence'}), const Export.imageSequence());
      expect(() => decodeExport('mp4'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeExport(const {'mode': 'webm'}), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('video size codec', () {
    test('round-trips named and custom sizes', () {
      expect(encodeVideoSize(VideoSize.square), 'square');
      expect(decodeVideoSize('hd'), VideoSize.hd);
      expect(encodeVideoSize(const VideoSize(800, 600)), {'width': 800, 'height': 600});
      expect(decodeVideoSize(const {'width': 800, 'height': 600}), const VideoSize(800, 600));
    });

    test('rejects bad input', () {
      expect(() => decodeVideoSize('giant'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeVideoSize(const {'width': 800}), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeVideoSize(5), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('defaults codec', () {
    test('round-trips set fields and rejects a non-object', () {
      const defaults = Defaults(
        duration: Time.seconds(0.4),
        ease: Ease.smooth,
        stagger: Stagger.each(Time.frames(6)),
      );
      final decoded = decodeDefaults(encodeDefaults(defaults));
      expect(decoded, defaults);
      expect(decodeDefaults(const <String, Object?>{}), const Defaults());
      expect(() => decodeDefaults('x'), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('spring + keyframe edge cases', () {
    test('an empty spring object decodes to the defaults', () {
      expect(decodeSpring(const <String, Object?>{}), const Spring());
    });

    test('a keyframe round-trips every field', () {
      const full = Keyframe(
        opacity: 0.5,
        x: 0.1,
        y: 0.2,
        scale: 1.1,
        scaleX: 1.2,
        scaleY: 1.3,
        rotation: 0.25,
        skewX: 0.01,
        skewY: 0.02,
        blur: 4,
        color: Color(0xFF010203),
        origin: Alignment.bottomRight,
      );
      expect(decodeKeyframe(encodeKeyframe(full)), full);
    });

    test('a non-string font family is dropped', () {
      expect(decodeTextStyle(const {'fontFamily': 123}).fontFamily, isNull);
      expect(
        encodeTextStyle(const TextStyle(fontWeight: FontWeight.w300))['fontWeight'],
        'w300',
      );
    });
  });
}
