// WI-21 (D12, §8): the timeline binder maps a Timeline's placement plan onto its
// scene children so the timeline drives the elements (the §8 example never calls
// .animate() on its children). Each anchored child gets the timeline's animation
// placed at the resolved absolute start via Trigger.at; an unanchored child or an
// anchor with no placement passes through unchanged.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/runtime/timeline_binder.dart';
import 'package:fluvie/src/composition/timeline.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

Animation _enter(int frames) =>
    Animation.from(const Keyframe(opacity: 0), duration: Time.frames(frames), ease: Ease.linear);

/// The single MotionTarget wrapping the widget anchored to [anchor] in [bound].
MotionTarget _targetFor(List<Widget> bound, Anchor anchor) =>
    bound.whereType<MotionTarget>().firstWhere((t) => identical(t.anchor, anchor));

/// The bound animation's placement start, resolved at 30 fps: the binder
/// positions each placement with a scope-computed `Trigger.at`.
int _startFrameOf(Animation animation) {
  final trigger = animation.at as AbsoluteTrigger;
  return trigger.time.resolveFrames(const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 0));
}

void main() {
  group('bindTimeline', () {
    test('an anchored child gets the timeline animation at its absolute start', () {
      final title = Anchor('title');
      final anim = _enter(15);
      final tl = Timeline()..play(title, anim, at: const Trigger.at(Time.frames(10)));
      const child = Text('Title', textDirection: TextDirection.ltr);
      final bound = bindTimeline(tl, [child.animate(const [], anchor: title)]);

      final target = _targetFor(bound, title);
      expect(target.child, same(child));
      expect(target.animations, hasLength(1));
      expect(_startFrameOf(target.animations.single), 10);
    });

    test('preserves the original effect, phase, and timing of the placed animation', () {
      final title = Anchor('title');
      final anim = _enter(15);
      final tl = Timeline()..play(title, anim);
      final bound = bindTimeline(tl, [
        const Text('Title', textDirection: TextDirection.ltr).animate(const [], anchor: title),
      ]);
      final placed = _targetFor(bound, title).animations.single;
      expect(placed.effect, same(anim.effect));
      expect(placed.phase, anim.phase);
      expect(placed.timing, anim.timing);
    });

    test('multiple anchored children each get their own placement', () {
      final a = Anchor('a');
      final b = Anchor('b');
      final tl = Timeline()
        ..play(a, _enter(20))
        ..play(b, _enter(10));
      final bound = bindTimeline(tl, [
        const Text('A', textDirection: TextDirection.ltr).animate(const [], anchor: a),
        const Text('B', textDirection: TextDirection.ltr).animate(const [], anchor: b),
      ]);
      expect(_startFrameOf(_targetFor(bound, a).animations.single), 0);
      expect(_startFrameOf(_targetFor(bound, b).animations.single), 20);
    });

    test('a playAll stagger places each bullet at its own start', () {
      final one = Anchor('1');
      final two = Anchor('2');
      final tl = Timeline()..playAll([one, two], _enter(10), stagger: const Time.frames(4));
      final bound = bindTimeline(tl, [
        const Text('1', textDirection: TextDirection.ltr).animate(const [], anchor: one),
        const Text('2', textDirection: TextDirection.ltr).animate(const [], anchor: two),
      ]);
      expect(_startFrameOf(_targetFor(bound, one).animations.single), 0);
      expect(_startFrameOf(_targetFor(bound, two).animations.single), 4);
    });

    test('an unanchored child passes through untouched', () {
      final tl = Timeline()..play(Anchor('x'), _enter(10));
      const plain = SizedBox(width: 4, height: 4);
      final bound = bindTimeline(tl, const [plain]);
      expect(bound.single, same(plain));
    });

    test('an anchored child with no matching placement keeps its own animations', () {
      final orphan = Anchor('orphan');
      final tl = Timeline()..play(Anchor('other'), _enter(10));
      final own = _enter(5);
      final wrapped = const Text(
        'keep',
        textDirection: TextDirection.ltr,
      ).animate([own], anchor: orphan);
      final bound = bindTimeline(tl, [wrapped]);
      expect(bound.single, same(wrapped));
    });

    test('an empty timeline leaves children unchanged', () {
      final tl = Timeline();
      final children = [
        const Text('a', textDirection: TextDirection.ltr).animate(const [], anchor: Anchor('a')),
      ];
      final bound = bindTimeline(tl, children);
      expect(bound, same(children));
    });
  });
}
