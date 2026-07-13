import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

Video _deck(List<List<Widget>> scenes) => Video(
  width: 320,
  height: 180,
  scenes: [
    for (final children in scenes) Scene(duration: const Time.seconds(4), children: children),
  ],
);

void main() {
  group('shape', () {
    test('a scene without stops is one base step', () {
      final plans = compileSlidePlans(
        _deck([
          [
            const SizedBox().animate([Animation.fadeIn(duration: const Time.seconds(1))]),
          ],
        ]),
      );
      expect(plans, hasLength(1));
      final plan = plans.single;
      expect(plan.sceneIndex, 0);
      expect(plan.stepCount, 1);
      expect(plan.steps.single.index, 0);
      expect(plan.steps.single.stops, isEmpty);
      // The base entrance: the fadeIn settles 30 frames in.
      expect(plan.steps.single.entranceFrames, 30);
    });

    test('each Stop becomes one later step, in document order', () {
      final first = Stop.single(
        child: const SizedBox().animate([Animation.fadeIn(duration: const Time.seconds(1))]),
      );
      final second = Stop.single(
        child: const SizedBox().animate([Animation.fadeIn(duration: const Time.seconds(2))]),
      );
      final plans = compileSlidePlans(
        _deck([
          [const Text('base'), first, second],
        ]),
      );
      final plan = plans.single;
      expect(plan.stepCount, 3);
      expect(plan.steps[0].stops, isEmpty);
      expect(plan.steps[1].stops, [same(first)]);
      expect(plan.steps[2].stops, [same(second)]);
      expect(plan.steps[1].entranceFrames, 30);
      expect(plan.steps[2].entranceFrames, 60);
    });

    test('a step with several elements settles on the slowest entrance', () {
      final stop = Stop(
        children: [
          const SizedBox().animate([Animation.fadeIn(duration: const Time.seconds(1))]),
          const SizedBox().animate([
            Animation.fadeIn(delay: const Time.seconds(1), duration: const Time.seconds(1)),
          ]),
        ],
      );
      final plans = compileSlidePlans(
        _deck([
          [stop],
        ]),
      );
      expect(plans.single.steps[1].entranceFrames, 60);
    });

    test('a stop with no entrances settles immediately', () {
      final stop = Stop.single(child: const SizedBox());
      final plans = compileSlidePlans(
        _deck([
          [stop],
        ]),
      );
      expect(plans.single.steps[1].entranceFrames, 0);
    });

    test('entrances measure scene-relative in later scenes', () {
      final stop = Stop.single(
        child: const SizedBox().animate([Animation.fadeIn(duration: const Time.seconds(1))]),
      );
      final plans = compileSlidePlans(
        _deck([
          [const Text('scene 0')],
          [stop],
        ]),
      );
      expect(plans, hasLength(2));
      expect(plans[1].sceneIndex, 1);
      // Frame 30 after ITS scene start, not frame 150 of the video.
      expect(plans[1].steps[1].entranceFrames, 30);
    });
  });

  group('ordering', () {
    test('an explicit order overrides the document position', () {
      final closesLast = Stop.single(order: 5, child: const SizedBox(key: ValueKey('late')));
      final opens = Stop.single(order: 1, child: const SizedBox(key: ValueKey('early')));
      final plans = compileSlidePlans(
        _deck([
          [closesLast, opens],
        ]),
      );
      final plan = plans.single;
      expect(plan.steps[1].stops, [same(opens)]);
      expect(plan.steps[2].stops, [same(closesLast)]);
    });

    test('a duplicate explicit order is a compile error', () {
      final a = Stop.single(order: 1, child: const SizedBox());
      final b = Stop.single(order: 1, child: const SizedBox());
      expect(
        () => compileSlidePlans(
          _deck([
            [a, b],
          ]),
        ),
        throwsA(
          isA<StepCompileError>().having(
            (error) => error.message,
            'message',
            contains('order 1'),
          ),
        ),
      );
    });

    test('nested stops become separate later steps, parent first', () {
      final inner = Stop.single(
        child: const SizedBox().animate([Animation.fadeIn(duration: const Time.seconds(2))]),
      );
      final outer = Stop(
        children: [
          const SizedBox().animate([Animation.fadeIn(duration: const Time.seconds(1))]),
          inner,
        ],
      );
      final plans = compileSlidePlans(
        _deck([
          [outer],
        ]),
      );
      final plan = plans.single;
      expect(plan.stepCount, 3);
      expect(plan.steps[1].stops, [same(outer)]);
      expect(plan.steps[2].stops, [same(inner)]);
      // The outer step settles on its own element alone — the nested stop's
      // slower entrance belongs to the nested step.
      expect(plan.steps[1].entranceFrames, 30);
      expect(plan.steps[2].entranceFrames, 60);
    });
  });

  group('validation', () {
    test('a cross-element trigger inside a Stop is a compile error', () {
      final intro = Anchor('intro');
      final stop = Stop.single(
        child: const SizedBox().animate([Animation.fadeIn(at: Trigger.whenEnds(intro))]),
      );
      expect(
        () => compileSlidePlans(
          _deck([
            [
              const SizedBox().animate([Animation.fadeIn()], anchor: intro),
              stop,
            ],
          ]),
        ),
        throwsA(
          isA<StepCompileError>().having(
            (error) => error.message,
            'message',
            contains('resolve locally'),
          ),
        ),
      );
    });

    test('a beat trigger inside a Stop is a compile error, not a resolver throw', () {
      // Note the beat sits INSIDE the stop: introspection of the authored
      // video would throw beatless-grid first, so the compiler reports the
      // stop constraint before resolving.
      final stop = Stop.single(
        child: const SizedBox().animate([Animation.fadeIn(at: const Trigger.beat())]),
      );
      expect(
        () => compileSlidePlans(
          _deck([
            [stop],
          ]),
        ),
        throwsA(isA<StepCompileError>()),
      );
    });
  });

  group('value surfaces', () {
    test('plans and steps describe themselves', () {
      const step = SlideStep(index: 1, stops: [], entranceFrames: 30);
      const plan = SlidePlan(sceneIndex: 0, steps: [step]);
      expect(plan.stepCount, 1);
      expect(plan.toString(), 'SlidePlan(scene: 0, steps: 1)');
      expect(step.toString(), 'SlideStep(1, stops: 0, entrance: 30 frames)');
      expect(
        const StepCompileError('two stops').toString(),
        'StepCompileError: two stops',
      );
    });
  });
}
