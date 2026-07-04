import 'dart:typed_data' show ByteData;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/runtime/animation_pipeline.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

const _probeKey = Key('probe');
const _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60);
const _defaults = Defaults(duration: Time.frames(20), ease: Ease.linear);

const _child = SizedBox(width: 48, height: 48, child: ColoredBox(color: Color(0xFFFFAA33)));

/// A pixel effect held at full strength for the whole window so list order is
/// the only variable between the two renders.
Animation _grainHold() => Animation.custom(
  Animation.grain(0.4).effect,
  phase: AnimationPhase.during,
  repeat: const Repeat.forever(),
);

Widget _frameWith(List<Animation> animations) => Center(
  child: RepaintBoundary(
    key: _probeKey,
    child: SizedBox(
      width: 80,
      height: 80,
      child: ColoredBox(
        color: const Color(0xFF000000),
        child: Center(
          child: buildAnimatedFrame(
            child: _child,
            animations: animations,
            schedule: ElementSchedule(
              window: const ResolvedSpan(0, 60),
              spans: List.filled(animations.length, const ResolvedSpan(0, 20)),
              defaults: _defaults,
            ),
            elementScope: _scope,
            frame: 8,
          ),
        ),
      ),
    ),
  ),
);

Future<ByteData> _bytes(WidgetTester tester) async {
  final boundary = tester.renderObject(find.byKey(_probeKey)) as RenderRepaintBoundary;
  late final ByteData data;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    data = (await image.toByteData())!;
    image.dispose();
  });
  return data;
}

void main() {
  testWidgets('§27.6: transform-then-pixel and pixel-then-transform paint identical pixels', (
    tester,
  ) async {
    await tester.pumpWidget(_frameWith([Animation.slideFade(), _grainHold()]));
    final forward = await _bytes(tester);
    await tester.pumpWidget(_frameWith([_grainHold(), Animation.slideFade()]));
    final reversed = await _bytes(tester);
    expect(
      forward.buffer.asUint8List(),
      reversed.buffer.asUint8List(),
      reason: 'the pixel effect orders outermost regardless of list position',
    );
  });
}
