import 'package:flutter/animation.dart' show Curves;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/codecs/curve_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';
import 'package:fluvie/src/serialization/codecs/trigger_codec.dart';
import 'package:fluvie/src/serialization/scene_spec.dart';
import 'package:fluvie/src/serialization/video_spec.dart';

void main() {
  test('FluvieSpecError toString reads with and without a path', () {
    expect(FluvieSpecError('boom').toString(), 'FluvieSpecError: boom');
    expect(
      FluvieSpecError('boom', path: const ['a', 'b']).toString(),
      'FluvieSpecError: boom (at a.b)',
    );
  });

  test('AnchorTable exposes resolved ids in first-seen order', () {
    final table = AnchorTable()
      ..resolve('intro')
      ..resolve('outro')
      ..resolve('intro');
    expect(table.ids, ['intro', 'outro']);
  });

  test('encodeCurve rejects a curve outside the named eases', () {
    expect(() => encodeCurve(Curves.easeOutQuart), throwsA(isA<FluvieSpecError>()));
  });

  test('decodeTime reports each malformed unit', () {
    expect(() => decodeTime('abms'), throwsA(isA<FluvieSpecError>()));
    expect(() => decodeTime('xf'), throwsA(isA<FluvieSpecError>()));
    expect(() => decodeTime('ys'), throwsA(isA<FluvieSpecError>()));
  });

  test('a beat trigger with a track anchor round-trips', () {
    final anchors = AnchorTable();
    final json = encodeTrigger(BeatTrigger(every: 2, track: Anchor('beat')));
    final decoded = decodeTrigger(json, anchors) as BeatTrigger;
    expect(decoded.every, 2);
    expect(decoded.track, same(anchors.resolve('beat')));
  });

  test('a hand-built VideoSpec gets a fresh anchor table and builds', () {
    final spec = VideoSpec(scenes: [SceneSpec(duration: const Time.frames(30))]);
    expect(spec.anchors.ids, isEmpty);
    expect(spec.build().totalFrames, 30);
  });

  test('VideoSpec.fromJson rejects a non-object scene', () {
    expect(
      () => VideoSpec.fromJson(const {
        'scenes': ['not a scene'],
      }),
      throwsA(isA<FluvieSpecError>()),
    );
  });

  test('SceneSpec.fromJson rejects a non-object background', () {
    expect(
      () => SceneSpec.fromJson(const {'duration': '1s', 'background': 'no'}, AnchorTable()),
      throwsA(isA<FluvieSpecError>()),
    );
  });
}
