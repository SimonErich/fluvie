// WI-20 (D12, §8) — SEAM CLOSES `TimelineSchedule`. The real `Timeline` is a
// GSAP-style mutable builder: play/playAll/wait/label record steps against a
// running playhead and a fixed fps; `at:` pattern-matches Trigger | String |
// LabelRef; `duration` is the max step end; the placement plan exposes each
// step's resolved absolute start. The §8 4-step example derives the exact total.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/timeline.dart';
import 'package:fluvie/src/composition/timeline_label.dart';
import 'package:fluvie/src/composition/timeline_schedule.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// An enter lasting [frames] frames, linear.
Animation _enter(int frames) =>
    Animation.from(const Keyframe(opacity: 0), duration: Time.frames(frames), ease: Ease.linear);

/// The placement for [target] in [timeline]'s plan.
TimelinePlacement _placementFor(Timeline timeline, Anchor target) =>
    timeline.placementsAt(30).firstWhere((p) => identical(p.target, target));

/// The schedule duration resolved at 30 fps (the scope-computed [Time] has no
/// eager value; the timeline resolves at the consuming video's fps).
int _durationFrames(Timeline timeline) => timeline.duration.resolveFrames(
  const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 0),
);

void main() {
  group('Timeline is a TimelineSchedule', () {
    test('implements the seam contract', () {
      expect(Timeline(), isA<TimelineSchedule>());
    });

    test('an empty timeline has zero duration', () {
      expect(_durationFrames(Timeline()), 0);
    });
  });

  group('play advances the playhead by the animation duration', () {
    test('a single play sets duration to the animation length', () {
      final title = Anchor('title');
      final tl = Timeline()..play(title, _enter(20));
      expect(_durationFrames(tl), 20);
      expect(_placementFor(tl, title).startFrame, 0);
    });

    test('two sequential plays stack back to back', () {
      final a = Anchor('a');
      final b = Anchor('b');
      final tl = Timeline()
        ..play(a, _enter(20))
        ..play(b, _enter(10));
      expect(_placementFor(tl, a).startFrame, 0);
      expect(_placementFor(tl, b).startFrame, 20);
      expect(_durationFrames(tl), 30);
    });

    test('a play with no explicit duration uses the Defaults duration', () {
      final a = Anchor('a');
      final tl = Timeline(defaults: const Defaults(duration: Time.frames(15)))
        ..play(a, Animation.fadeIn());
      expect(_durationFrames(tl), 15);
    });
  });

  group('wait advances the playhead without a step', () {
    test('a wait pushes the next play later', () {
      final a = Anchor('a');
      final tl = Timeline()
        ..wait(const Time.frames(12))
        ..play(a, _enter(10));
      expect(_placementFor(tl, a).startFrame, 12);
      expect(_durationFrames(tl), 22);
    });
  });

  group('at: placement', () {
    test('Trigger.at places a step at an absolute time', () {
      final a = Anchor('a');
      final tl = Timeline()..play(a, _enter(10), at: const Trigger.at(Time.frames(40)));
      expect(_placementFor(tl, a).startFrame, 40);
      expect(_durationFrames(tl), 50);
    });

    test('Trigger.whenEnds chains after the named anchor ends', () {
      final a = Anchor('a');
      final b = Anchor('b');
      final tl = Timeline()
        ..play(a, _enter(30))
        ..wait(const Time.frames(100)) // move the playhead far past a's end
        ..play(b, _enter(10), at: Trigger.whenEnds(a));
      expect(_placementFor(tl, b).startFrame, 30); // right after a, not the playhead
    });

    test('Trigger.previous chains after the previous step', () {
      final a = Anchor('a');
      final b = Anchor('b');
      final tl = Timeline()
        ..play(a, _enter(25))
        ..play(b, _enter(10), at: Trigger.previous);
      expect(_placementFor(tl, b).startFrame, 25);
    });

    test('a String label places a step at the label position', () {
      final a = Anchor('a');
      final b = Anchor('b');
      final tl = Timeline()
        ..play(a, _enter(20))
        ..label('mark')
        ..wait(const Time.frames(50))
        ..play(b, _enter(10), at: 'mark');
      expect(_placementFor(tl, b).startFrame, 20);
    });

    test('a LabelRef with a negative offset places a step before the label', () {
      final a = Anchor('a');
      final b = Anchor('b');
      final tl = Timeline()
        ..play(a, _enter(30))
        ..label('reveal')
        ..play(b, _enter(10), at: 'reveal'.label - 0.2.seconds);
      expect(_placementFor(tl, b).startFrame, 24); // 30 - 6 (0.2s @ 30fps)
    });

    test('Trigger.whenStarts chains off the named anchor start', () {
      final a = Anchor('a');
      final b = Anchor('b');
      final tl = Timeline()
        ..wait(const Time.frames(40))
        ..play(a, _enter(30)) // starts at 40
        ..wait(const Time.frames(100))
        ..play(b, _enter(10), at: Trigger.whenStarts(a));
      // b aligns to a's recorded start (40), not the far-advanced playhead.
      expect(_placementFor(tl, b).startFrame, 40);
    });

    test('Trigger.whenStarts on an unplaced anchor falls back to the playhead', () {
      final ghost = Anchor('ghost');
      final b = Anchor('b');
      final tl = Timeline()
        ..wait(const Time.frames(12))
        ..play(b, _enter(10), at: Trigger.whenStarts(ghost));
      // No placement exists for ghost, so whenStarts resolves to the playhead.
      expect(_placementFor(tl, b).startFrame, 12);
    });

    test('an unknown label throws', () {
      final a = Anchor('a');
      expect(
        () => Timeline()..play(a, _enter(10), at: 'missing'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('an unsupported at: type throws', () {
      final a = Anchor('a');
      expect(
        () => Timeline()..play(a, _enter(10), at: 42),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('playAll distributes starts', () {
    test('a stagger offsets each target from the base start', () {
      final one = Anchor('1');
      final two = Anchor('2');
      final three = Anchor('3');
      final tl = Timeline()..playAll([one, two, three], _enter(10), stagger: const Time.frames(4));
      expect(_placementFor(tl, one).startFrame, 0);
      expect(_placementFor(tl, two).startFrame, 4);
      expect(_placementFor(tl, three).startFrame, 8);
    });

    test('without a stagger every target starts together', () {
      final one = Anchor('1');
      final two = Anchor('2');
      final tl = Timeline()..playAll([one, two], _enter(10));
      expect(_placementFor(tl, one).startFrame, 0);
      expect(_placementFor(tl, two).startFrame, 0);
    });

    test('duration covers the last-staggered target end', () {
      final one = Anchor('1');
      final two = Anchor('2');
      final tl = Timeline()..playAll([one, two], _enter(10), stagger: const Time.frames(4));
      // last target starts at 4, lasts 10 -> ends at 14.
      expect(_durationFrames(tl), 14);
      // playhead advances to the union end so the next play follows it.
      final after = Anchor('after');
      tl.play(after, _enter(5));
      expect(_placementFor(tl, after).startFrame, 14);
    });
  });

  group('the §8 four-step example derives the exact duration', () {
    test('play + after + wait + playAll + play(at: label)', () {
      final title = Anchor('title');
      final subtitle = Anchor('subtitle');
      final one = Anchor('b1');
      final two = Anchor('b2');
      final cta = Anchor('cta');
      // Defaults duration 0.5s @ 30fps = 15 frames for the preset animations.
      final tl = Timeline(defaults: const Defaults(duration: Time.seconds(0.5)))
        ..play(title, Animation.from(const Keyframe(y: 1)))
        ..play(subtitle, Animation.fadeIn(), at: Trigger.whenEnds(title))
        ..wait(0.3.seconds)
        ..playAll([one, two], Animation.from(const Keyframe(x: -0.3)), stagger: 0.08.seconds)
        ..label('reveal')
        ..play(cta, Animation.pop(), at: 'reveal'.label - 0.2.seconds);

      // title: 0..15 ; subtitle: after(title)=15..30 ; wait 0.3s=9 -> playhead 39
      expect(_placementFor(tl, title).startFrame, 0);
      expect(_placementFor(tl, subtitle).startFrame, 15);
      // bullets at playhead 39, stagger 0.08s = 2.4 -> rounds to 2 frames.
      expect(_placementFor(tl, one).startFrame, 39);
      expect(_placementFor(tl, two).startFrame, 41);
      // each bullet lasts 15 -> last ends at 41 + 15 = 56 -> playhead 56.
      // label('reveal') records 56 ; cta at reveal - 0.2s(6) = 50.
      expect(_placementFor(tl, cta).startFrame, 50);
    });
  });

  group('placement plan is value-correct', () {
    test('each placement carries its target, animation, and absolute start', () {
      final a = Anchor('a');
      final anim = _enter(10);
      final tl = Timeline()..play(a, anim, at: const Trigger.at(Time.frames(7)));
      final placement = tl.placementsAt(30).single;
      expect(identical(placement.target, a), isTrue);
      expect(identical(placement.animation, anim), isTrue);
      expect(placement.start, const Time.frames(7));
      expect(placement.startFrame, 7);
    });

    test('startFrame throws when the start is not an absolute frame Time', () {
      final placement = TimelinePlacement(
        target: Anchor('a'),
        animation: _enter(10),
        start: const Time.seconds(1), // relative/seconds, not a FrameTime
        durationFrames: 10,
      );
      expect(
        () => placement.startFrame,
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('absolute'))),
      );
    });

    test('toString names the target, start, and frame length', () {
      final placement = TimelinePlacement(
        target: Anchor('hero'),
        animation: _enter(10),
        start: const Time.frames(7),
        durationFrames: 10,
      );
      expect(placement.toString(), contains('start: '));
      expect(placement.toString(), contains('frames: 10'));
    });
  });
}
