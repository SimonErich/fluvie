import 'package:flutter/painting.dart' show Alignment, Color, FontWeight, TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/stagger_origin.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/codecs/alignment_codec.dart';
import 'package:fluvie/src/serialization/codecs/color_codec.dart';
import 'package:fluvie/src/serialization/codecs/curve_codec.dart';
import 'package:fluvie/src/serialization/codecs/enum_codec.dart';
import 'package:fluvie/src/serialization/codecs/keyframe_codec.dart';
import 'package:fluvie/src/serialization/codecs/motion_codec.dart';
import 'package:fluvie/src/serialization/codecs/text_style_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';
import 'package:fluvie/src/serialization/codecs/trigger_codec.dart';

void main() {
  group('time codec', () {
    test('round-trips every unit', () {
      for (final time in <Time>[
        const Time.frames(30),
        const Time.seconds(2.5),
        const Time.ms(500),
        const Time.relative(0.3),
        const Time.relative(0.2, max: Time.seconds(0.8)),
        Time.zero,
      ]) {
        expect(decodeTime(encodeTime(time)), time);
      }
    });

    test('encodes the canonical strings', () {
      expect(encodeTime(const Time.frames(30)), '30f');
      expect(encodeTime(const Time.ms(500)), '500ms');
      expect(encodeTime(const Time.relative(0.2, max: Time.seconds(0.8))), '0.2r@0.8s');
    });

    test('rejects composites and malformed strings', () {
      expect(
        () => encodeTime(const Time.frames(1) + const Time.ms(1)),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(() => decodeTime(42), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeTime('soon'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeTime('xr'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeTime('0.2r#bad'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeTime('12x'), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('color codec', () {
    test('round-trips through 8-digit hex', () {
      const color = Color(0x80123456);
      expect(encodeColor(color), '#80123456');
      expect(decodeColor(encodeColor(color)), color);
    });

    test('accepts 6-digit hex as opaque', () {
      expect(decodeColor('#FFFFFF'), const Color(0xFFFFFFFF));
    });

    test('rejects invalid hex', () {
      expect(() => decodeColor('white'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeColor('#FFF'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeColor('#GGGGGG'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeColor(7), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('curve codec', () {
    test('round-trips named eases (canonical name wins)', () {
      expect(encodeCurve(Ease.smooth), 'smooth');
      expect(decodeCurve('smooth'), Ease.smooth);
      expect(decodeCurve('snappy'), Ease.snappy);
    });

    test('rejects unknown and unsupported curves', () {
      expect(() => decodeCurve('zoomy'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeCurve(3), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('alignment codec', () {
    test('round-trips named and custom alignments', () {
      expect(encodeAlignment(Alignment.center), 'center');
      expect(decodeAlignment('topLeft'), Alignment.topLeft);
      expect(encodeAlignment(const Alignment(0.25, -0.5)), {'x': 0.25, 'y': -0.5});
      expect(decodeAlignment(const {'x': 0.25, 'y': -0.5}), const Alignment(0.25, -0.5));
    });

    test('rejects unknown names and shapes', () {
      expect(() => decodeAlignment('middle'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeAlignment(5), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('enum codec', () {
    test('round-trips by name', () {
      expect(encodeEnum(StaggerOrigin.center), 'center');
      expect(decodeEnum(StaggerOrigin.values, 'edges', 'origin'), StaggerOrigin.edges);
    });

    test('rejects unknown and non-string', () {
      expect(
        () => decodeEnum(StaggerOrigin.values, 'middle', 'origin'),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(() => decodeEnum(StaggerOrigin.values, 9, 'origin'), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('keyframe codec', () {
    test('round-trips only the overridden fields', () {
      const keyframe = Keyframe(opacity: 0, y: 0.3, color: Color(0xFF00FF00));
      final json = encodeKeyframe(keyframe);
      expect(json.keys, containsAll(<String>['opacity', 'y', 'color']));
      expect(json.containsKey('scale'), isFalse);
      expect(decodeKeyframe(json), keyframe);
    });

    test('round-trips a non-default origin', () {
      const keyframe = Keyframe(scale: 0, origin: Alignment.topLeft);
      expect(decodeKeyframe(encodeKeyframe(keyframe)), keyframe);
    });

    test('rejects a non-object', () {
      expect(() => decodeKeyframe('nope'), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('trigger codec', () {
    test('round-trips keyword triggers', () {
      final anchors = AnchorTable();
      for (final trigger in <Trigger>[
        Trigger.auto,
        Trigger.sceneStart,
        Trigger.sceneEnd,
        Trigger.previous,
      ]) {
        expect(decodeTrigger(encodeTrigger(trigger), anchors), trigger);
      }
    });

    test('round-trips at and beat', () {
      final anchors = AnchorTable();
      expect(
        decodeTrigger(encodeTrigger(const Trigger.at(Time.seconds(1))), anchors),
        const Trigger.at(Time.seconds(1)),
      );
      final beat = encodeTrigger(const Trigger.beat(every: 2));
      expect(decodeTrigger(beat, anchors), const Trigger.beat(every: 2));
    });

    test('resolves anchor references to one canonical instance', () {
      final anchors = AnchorTable();
      final json = encodeTrigger(Trigger.whenEnds(Anchor('intro')));
      final decoded = decodeTrigger(json, anchors) as WhenEndsTrigger;
      final again =
          decodeTrigger(encodeTrigger(Trigger.whenStarts(Anchor('intro'))), anchors)
              as WhenStartsTrigger;
      expect(identical(decoded.anchor, again.anchor), isTrue);
      expect(decoded.anchor.debugName, 'intro');
    });

    test('rejects anchors without an id and unknown forms', () {
      expect(() => encodeTrigger(Trigger.whenEnds(Anchor())), throwsA(isA<FluvieSpecError>()));
      final anchors = AnchorTable();
      expect(() => decodeTrigger('whenever', anchors), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeTrigger(const {'kind': 'nope'}, anchors), throwsA(isA<FluvieSpecError>()));
      expect(
        () => decodeTrigger(const {'kind': 'whenEnds'}, anchors),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(() => decodeTrigger(7, anchors), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('motion codec', () {
    test('round-trips springs (named and custom)', () {
      expect(encodeSpring(Spring.snappy), 'snappy');
      expect(decodeSpring('snappy'), Spring.snappy);
      const custom = Spring(stiffness: 200, damping: 15, mass: 2);
      expect(decodeSpring(encodeSpring(custom)), custom);
      expect(() => decodeSpring('zippy'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeSpring(3), throwsA(isA<FluvieSpecError>()));
    });

    test('round-trips staggers', () {
      for (final stagger in <Stagger>[
        const Stagger.each(Time.frames(8)),
        const Stagger.evenly(over: Time.seconds(1)),
        const Stagger.from(StaggerOrigin.center),
        const Stagger.from(StaggerOrigin.edges, gap: Time.frames(3)),
      ]) {
        expect(decodeStagger(encodeStagger(stagger)), stagger);
      }
      expect(() => decodeStagger(const {'bogus': 1}), throwsA(isA<FluvieSpecError>()));
    });

    test('round-trips repeats', () {
      for (final repeat in <Repeat>[
        const Repeat.forever(),
        const Repeat.forever(yoyo: true),
        const Repeat.times(3),
        const Repeat.times(2, yoyo: true, gap: Time.frames(6)),
      ]) {
        expect(decodeRepeat(encodeRepeat(repeat)), repeat);
      }
      expect(() => decodeRepeat(const {'bogus': 1}), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('text style codec', () {
    test('round-trips the supported subset', () {
      const style = TextStyle(
        color: Color(0xFF112233),
        fontSize: 48,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
        letterSpacing: 1.5,
        height: 1.2,
      );
      final json = encodeTextStyle(style);
      final decoded = decodeTextStyle(json);
      expect(decoded.color, style.color);
      expect(decoded.fontSize, 48);
      expect(decoded.fontWeight, FontWeight.w700);
      expect(decoded.fontFamily, 'Inter');
      expect(decoded.letterSpacing, 1.5);
      expect(decoded.height, 1.2);
    });

    test('accepts bold and normal aliases', () {
      expect(decodeTextStyle(const {'fontWeight': 'bold'}).fontWeight, FontWeight.bold);
      expect(decodeTextStyle(const {'fontWeight': 'normal'}).fontWeight, FontWeight.normal);
    });

    test('rejects bad input', () {
      expect(() => decodeTextStyle('big'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeTextStyle(const {'fontWeight': 'heavy'}), throwsA(isA<FluvieSpecError>()));
    });
  });
}
