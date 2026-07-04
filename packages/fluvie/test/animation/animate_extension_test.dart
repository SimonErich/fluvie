import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';

const _square = SizedBox(width: 20, height: 20);

void main() {
  group('.animate()', () {
    test('returns a MotionTarget carrying every argument verbatim', () {
      final animations = [Animation.from(const Keyframe(opacity: 0))];
      final anchor = Anchor('hero');
      final window = 1.seconds.to(3.seconds);
      const defaults = Defaults(duration: Time.frames(10));

      final result = _square.animate(
        animations,
        anchor: anchor,
        window: window,
        defaults: defaults,
      );

      final target = result as MotionTarget;
      expect(target.animations, same(animations));
      expect(target.anchor, same(anchor));
      expect(target.window, same(window));
      expect(target.defaults, defaults);
      expect(target.child, same(_square));
    });
  });

  group('.show()', () {
    test('builds the window (from ?? zero).to(to ?? whole window)', () {
      final shown = _square.show(from: 10.frames) as MotionTarget;
      expect(shown.animations, isEmpty);
      expect(shown.window!.start, const Time.frames(10));
      expect(shown.window!.end, const Time.relative(1));

      final until = _square.show(to: 40.frames) as MotionTarget;
      expect(until.window!.start, Time.zero);
      expect(until.window!.end, const Time.frames(40));
    });

    test('with both bounds null the window stays null — no pointless scope (D16)', () {
      final shown = _square.show() as MotionTarget;
      expect(shown.animations, isEmpty);
      expect(shown.window, isNull);
    });

    test('show then animate stacks per the §25 example shape', () {
      final animations = [Animation.from(const Keyframe(opacity: 0))];
      final stacked =
          _square.show(from: 0.33.relative, to: 0.66.relative).animate(animations) as MotionTarget;

      // The outer target carries the animations; the inner one the window.
      expect(stacked.animations, same(animations));
      expect(stacked.window, isNull);
      final inner = stacked.child as MotionTarget;
      expect(inner.animations, isEmpty);
      expect(inner.window!.start, const Time.relative(0.33));
      expect(inner.window!.end, const Time.relative(0.66));
      expect(inner.child, same(_square));
    });
  });
}
