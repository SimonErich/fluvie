import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  group('scene bounds', () {
    test('cut scenes sit back to back and match the Video offsets', () {
      final video = Video(
        scenes: const [
          Scene(duration: Time.seconds(2)),
          Scene(duration: Time.seconds(1)),
        ],
      );
      final introspection = introspectTimeline(video);
      expect(introspection.fps, 30);
      expect(introspection.totalFrames, video.totalFrames);
      expect(introspection.scenes, hasLength(2));
      expect(introspection.scenes[0].span, const FrameSpan(0, 60));
      expect(introspection.scenes[1].span, const FrameSpan(60, 90));
      expect(introspection.scenes[1].span.durationFrames, 30);
    });

    test('an overlapping transition starts the next scene early', () {
      final video = Video(
        transition: const Transition.crossFade(Time.seconds(0.5)),
        scenes: const [
          Scene(duration: Time.seconds(2)),
          Scene(duration: Time.seconds(2)),
        ],
      );
      final introspection = introspectTimeline(video);
      expect(introspection.scenes[1].span.start, 45);
      expect(introspection.totalFrames, 105);
      expect(introspection.totalFrames, video.totalFrames);
    });
  });

  group('element windows and animations', () {
    test('a window-less element spans its whole scene', () {
      final video = Video(
        scenes: [
          Scene(
            duration: const Time.seconds(2),
            children: [
              const SizedBox().animate([Animation.fadeIn(duration: const Time.seconds(1))]),
            ],
          ),
        ],
      );
      final introspection = introspectTimeline(video);
      final element = introspection.scenes[0].elements.single;
      expect(element.window, const FrameSpan(0, 60));
      expect(element.animations, hasLength(1));
      expect(element.animations.single.phase, AnimationPhase.enter);
      expect(element.animations.single.span, const FrameSpan(0, 30));
      expect(element.enterSpan, const FrameSpan(0, 30));
    });

    test('windows resolve absolutely, exits anchor to the window end', () {
      final video = Video(
        scenes: [
          const Scene(duration: Time.seconds(1)),
          Scene(
            duration: const Time.seconds(2),
            children: [
              const SizedBox().animate(
                [Animation.fadeOut(duration: const Time.seconds(0.5))],
                window: const TimeRange(Time.seconds(0.5), Time.seconds(1.5)),
              ),
            ],
          ),
        ],
      );
      final introspection = introspectTimeline(video);
      // Scene 1 starts at frame 30; its element window is scene-relative
      // 15..45, so absolute 45..75.
      final exiting = introspection.scenes[1].elements.single;
      expect(exiting.window, const FrameSpan(45, 75));
      expect(exiting.animations.single.phase, AnimationPhase.exit);
      // End-anchored: the exit finishes on the window end.
      expect(exiting.animations.single.span, const FrameSpan(60, 75));
      expect(exiting.enterSpan, isNull);
    });

    test('a nested window-less element inherits the enclosing window', () {
      final video = Video(
        scenes: [
          Scene(
            duration: const Time.seconds(2),
            children: [
              Column(
                children: [
                  const SizedBox().animate([
                    Animation.fadeIn(duration: const Time.seconds(0.5)),
                  ]),
                ],
              ).show(from: const Time.seconds(1)),
            ],
          ),
        ],
      );
      final introspection = introspectTimeline(video);
      final inner = introspection.scenes[0].elements.firstWhere(
        (element) => element.animations.isNotEmpty,
      );
      expect(inner.window, const FrameSpan(30, 60));
      expect(inner.animations.single.span, const FrameSpan(30, 45));
    });

    test('cross-element triggers resolve to absolute frames', () {
      final intro = Anchor('intro');
      final video = Video(
        scenes: [
          Scene(
            duration: const Time.seconds(4),
            children: [
              const SizedBox().animate([
                Animation.fadeIn(duration: const Time.seconds(1)),
              ], anchor: intro),
              const SizedBox().animate([
                Animation.fadeIn(at: Trigger.whenEnds(intro), duration: const Time.seconds(1)),
              ]),
            ],
          ),
        ],
      );
      final introspection = introspectTimeline(video);
      final chained = introspection.scenes[0].elements[1];
      expect(chained.animations.single.span, const FrameSpan(30, 60));
    });

    test('a beat trigger without a grid throws the honest timing error', () {
      final video = Video(
        scenes: [
          Scene(
            duration: const Time.seconds(1),
            children: [
              const SizedBox().animate([Animation.fadeIn(at: const Trigger.beat())]),
            ],
          ),
        ],
      );
      expect(() => introspectTimeline(video), throwsA(isA<FluvieTimingError>()));
    });
  });

  group('identity lookups', () {
    test('elements resolve by anchor, key, and widget instance', () {
      final logo = Anchor('logo');
      final keyed = const SizedBox(key: ValueKey('title')).animate([Animation.fadeIn()]);
      final anchored = const SizedBox().animate([Animation.fadeIn()], anchor: logo);
      final video = Video(
        scenes: [
          Scene(duration: const Time.seconds(2), children: [keyed, anchored]),
        ],
      );
      final introspection = introspectTimeline(video);
      expect(introspection.elementForAnchor(logo), isNotNull);
      expect(introspection.elementForAnchor(logo)!.anchor, same(logo));
      expect(introspection.elementForKey(const ValueKey('title')), isNotNull);
      expect(introspection.elementFor(keyed), isNotNull);
      expect(introspection.elementFor(keyed)!.key, const ValueKey('title'));
      expect(introspection.elementFor(anchored), same(introspection.elementForAnchor(logo)));
      expect(introspection.elementForAnchor(Anchor('logo')), isNull);
    });

    test('elementsIn returns the elements of a subtree in walk order', () {
      final bullets = Column(
        children: [
          const SizedBox().animate([Animation.fadeIn()]),
          const SizedBox().animate([Animation.fadeIn()]),
        ],
      );
      final aside = const SizedBox().animate([Animation.fadeIn()]);
      final video = Video(
        scenes: [
          Scene(duration: const Time.seconds(2), children: [bullets, aside]),
        ],
      );
      final introspection = introspectTimeline(video);
      final inBullets = introspection.elementsIn(bullets);
      expect(inBullets, hasLength(2));
      expect(introspection.scenes[0].elements, hasLength(3));
      expect(inBullets, isNot(contains(introspection.elementFor(aside))));
    });

    test('ownerIds are stable and scene-scoped', () {
      final video = Video(
        scenes: [
          Scene(
            duration: const Time.seconds(1),
            children: [
              const SizedBox().animate([Animation.fadeIn()]),
            ],
          ),
          Scene(
            duration: const Time.seconds(1),
            children: [
              const SizedBox().animate([Animation.fadeIn()]),
            ],
          ),
        ],
      );
      final introspection = introspectTimeline(video);
      final first = introspection.scenes[0].elements.single;
      final second = introspection.scenes[1].elements.single;
      expect(first.sceneIndex, 0);
      expect(second.sceneIndex, 1);
      expect(first.ownerId, isNot(second.ownerId));
    });
  });

  group('determinism', () {
    test('introspecting the same video twice yields equal values', () {
      final video = Video(
        scenes: [
          Scene(
            duration: const Time.seconds(2),
            children: [
              const SizedBox().animate([Animation.fadeIn(duration: const Time.seconds(1))]),
            ],
          ),
        ],
      );
      final first = introspectTimeline(video);
      final second = introspectTimeline(video);
      expect(first.totalFrames, second.totalFrames);
      expect(first.scenes[0].span, second.scenes[0].span);
      expect(
        first.scenes[0].elements.single.window,
        second.scenes[0].elements.single.window,
      );
      expect(
        first.scenes[0].elements.single.animations.single.span,
        second.scenes[0].elements.single.animations.single.span,
      );
    });

    test('a Scene.sequence timeline scene introspects through its bound children', () {
      final title = Anchor('title');
      final timeline = Timeline()..play(title, Animation.fadeIn(duration: const Time.seconds(1)));
      final video = Video(
        scenes: [
          Scene.sequence(
            timeline: timeline,
            children: [
              const SizedBox().animate(const [], anchor: title),
            ],
          ),
        ],
      );
      final introspection = introspectTimeline(video);
      final element = introspection.elementForAnchor(title);
      expect(element, isNotNull);
      expect(element!.animations, isNotEmpty);
    });
  });
}
