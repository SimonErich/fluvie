import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/core/scene_transition.dart';

void main() {
  group('SceneTransitionType', () {
    test('has all expected types', () {
      expect(SceneTransitionType.values, contains(SceneTransitionType.none));
      expect(SceneTransitionType.values, contains(SceneTransitionType.crossFade));
      expect(SceneTransitionType.values, contains(SceneTransitionType.slideLeft));
      expect(SceneTransitionType.values, contains(SceneTransitionType.slideRight));
      expect(SceneTransitionType.values, contains(SceneTransitionType.slideUp));
      expect(SceneTransitionType.values, contains(SceneTransitionType.slideDown));
      expect(SceneTransitionType.values, contains(SceneTransitionType.scale));
      expect(SceneTransitionType.values, contains(SceneTransitionType.wipe));
      expect(SceneTransitionType.values, contains(SceneTransitionType.zoomWarp));
      expect(SceneTransitionType.values, contains(SceneTransitionType.colorBleed));
    });
  });

  group('WipeDirection', () {
    test('has all expected directions', () {
      expect(WipeDirection.values, contains(WipeDirection.leftToRight));
      expect(WipeDirection.values, contains(WipeDirection.rightToLeft));
      expect(WipeDirection.values, contains(WipeDirection.topToBottom));
      expect(WipeDirection.values, contains(WipeDirection.bottomToTop));
    });
  });

  group('SceneTransition.none', () {
    test('creates with correct type', () {
      const transition = SceneTransition.none();
      expect(transition.type, SceneTransitionType.none);
    });

    test('has zero duration', () {
      const transition = SceneTransition.none();
      expect(transition.durationInFrames, 0);
    });

    test('uses linear curve', () {
      const transition = SceneTransition.none();
      expect(transition.curve, Curves.linear);
    });

    test('has null optional properties', () {
      const transition = SceneTransition.none();
      expect(transition.wipeDirection, isNull);
      expect(transition.zoomTarget, isNull);
      expect(transition.bleedColor, isNull);
    });
  });

  group('SceneTransition.crossFade', () {
    test('creates with correct type', () {
      const transition = SceneTransition.crossFade();
      expect(transition.type, SceneTransitionType.crossFade);
    });

    test('has default 15 frame duration', () {
      const transition = SceneTransition.crossFade();
      expect(transition.durationInFrames, 15);
    });

    test('supports custom duration', () {
      const transition = SceneTransition.crossFade(durationInFrames: 30);
      expect(transition.durationInFrames, 30);
    });

    test('uses easeInOut curve by default', () {
      const transition = SceneTransition.crossFade();
      expect(transition.curve, Curves.easeInOut);
    });

    test('supports custom curve', () {
      const transition = SceneTransition.crossFade(curve: Curves.linear);
      expect(transition.curve, Curves.linear);
    });
  });

  group('SceneTransition.slideLeft', () {
    test('creates with correct type', () {
      const transition = SceneTransition.slideLeft();
      expect(transition.type, SceneTransitionType.slideLeft);
    });

    test('has default 20 frame duration', () {
      const transition = SceneTransition.slideLeft();
      expect(transition.durationInFrames, 20);
    });

    test('supports custom duration and curve', () {
      const transition = SceneTransition.slideLeft(
        durationInFrames: 40,
        curve: Curves.bounceOut,
      );
      expect(transition.durationInFrames, 40);
      expect(transition.curve, Curves.bounceOut);
    });
  });

  group('SceneTransition.slideRight', () {
    test('creates with correct type', () {
      const transition = SceneTransition.slideRight();
      expect(transition.type, SceneTransitionType.slideRight);
    });

    test('has default 20 frame duration', () {
      const transition = SceneTransition.slideRight();
      expect(transition.durationInFrames, 20);
    });
  });

  group('SceneTransition.slideUp', () {
    test('creates with correct type', () {
      const transition = SceneTransition.slideUp();
      expect(transition.type, SceneTransitionType.slideUp);
    });

    test('has default 20 frame duration', () {
      const transition = SceneTransition.slideUp();
      expect(transition.durationInFrames, 20);
    });
  });

  group('SceneTransition.slideDown', () {
    test('creates with correct type', () {
      const transition = SceneTransition.slideDown();
      expect(transition.type, SceneTransitionType.slideDown);
    });

    test('has default 20 frame duration', () {
      const transition = SceneTransition.slideDown();
      expect(transition.durationInFrames, 20);
    });
  });

  group('SceneTransition.scale', () {
    test('creates with correct type', () {
      const transition = SceneTransition.scale();
      expect(transition.type, SceneTransitionType.scale);
    });

    test('has default 20 frame duration', () {
      const transition = SceneTransition.scale();
      expect(transition.durationInFrames, 20);
    });

    test('supports custom duration and curve', () {
      const transition = SceneTransition.scale(
        durationInFrames: 25,
        curve: Curves.elasticOut,
      );
      expect(transition.durationInFrames, 25);
      expect(transition.curve, Curves.elasticOut);
    });
  });

  group('SceneTransition.wipe', () {
    test('creates with correct type', () {
      const transition = SceneTransition.wipe();
      expect(transition.type, SceneTransitionType.wipe);
    });

    test('has default 20 frame duration', () {
      const transition = SceneTransition.wipe();
      expect(transition.durationInFrames, 20);
    });

    test('has default leftToRight direction', () {
      const transition = SceneTransition.wipe();
      expect(transition.wipeDirection, WipeDirection.leftToRight);
    });

    test('supports custom wipe direction', () {
      const transition = SceneTransition.wipe(
        wipeDirection: WipeDirection.topToBottom,
      );
      expect(transition.wipeDirection, WipeDirection.topToBottom);
    });
  });

  group('SceneTransition.zoomWarp', () {
    test('creates with correct type', () {
      const transition = SceneTransition.zoomWarp();
      expect(transition.type, SceneTransitionType.zoomWarp);
    });

    test('has default 30 frame duration', () {
      const transition = SceneTransition.zoomWarp();
      expect(transition.durationInFrames, 30);
    });

    test('has default 3.0 maxZoom', () {
      const transition = SceneTransition.zoomWarp();
      expect(transition.maxZoom, 3.0);
    });

    test('uses easeInOutCubic curve by default', () {
      const transition = SceneTransition.zoomWarp();
      expect(transition.curve, Curves.easeInOutCubic);
    });

    test('supports custom maxZoom', () {
      const transition = SceneTransition.zoomWarp(maxZoom: 5.0);
      expect(transition.maxZoom, 5.0);
    });

    test('supports custom zoomTarget', () {
      const transition = SceneTransition.zoomWarp(
        zoomTarget: Alignment.topRight,
      );
      expect(transition.zoomTarget, Alignment.topRight);
    });
  });

  group('SceneTransition.colorBleed', () {
    test('creates with correct type', () {
      const transition = SceneTransition.colorBleed();
      expect(transition.type, SceneTransitionType.colorBleed);
    });

    test('has default 25 frame duration', () {
      const transition = SceneTransition.colorBleed();
      expect(transition.durationInFrames, 25);
    });

    test('has null bleedColor by default', () {
      const transition = SceneTransition.colorBleed();
      expect(transition.bleedColor, isNull);
    });

    test('supports custom bleedColor', () {
      const transition = SceneTransition.colorBleed(
        bleedColor: Color(0xFFFF0000),
      );
      expect(transition.bleedColor, const Color(0xFFFF0000));
    });
  });

  group('progressAt', () {
    test('returns 0.0 at frame 0', () {
      const transition = SceneTransition.crossFade(durationInFrames: 20);
      expect(transition.progressAt(0), 0.0);
    });

    test('returns 0.5 at midpoint', () {
      const transition = SceneTransition.crossFade(durationInFrames: 20);
      expect(transition.progressAt(10), 0.5);
    });

    test('returns 1.0 at end', () {
      const transition = SceneTransition.crossFade(durationInFrames: 20);
      expect(transition.progressAt(20), 1.0);
    });

    test('clamps to 1.0 past end', () {
      const transition = SceneTransition.crossFade(durationInFrames: 20);
      expect(transition.progressAt(30), 1.0);
    });

    test('clamps to 0.0 for negative frames', () {
      const transition = SceneTransition.crossFade(durationInFrames: 20);
      expect(transition.progressAt(-5), 0.0);
    });

    test('returns 1.0 when durationInFrames is 0', () {
      const transition = SceneTransition.none();
      expect(transition.progressAt(0), 1.0);
    });
  });

  group('curvedProgressAt', () {
    test('applies curve to progress', () {
      const transition = SceneTransition.crossFade(
        durationInFrames: 20,
        curve: Curves.linear,
      );
      expect(transition.curvedProgressAt(10), 0.5);
    });

    test('returns 0.0 at start', () {
      const transition = SceneTransition.crossFade(durationInFrames: 20);
      expect(transition.curvedProgressAt(0), 0.0);
    });

    test('returns 1.0 at end', () {
      const transition = SceneTransition.crossFade(durationInFrames: 20);
      expect(transition.curvedProgressAt(20), 1.0);
    });

    test('applies easeInOut curve at midpoint', () {
      const transition = SceneTransition.crossFade(
        durationInFrames: 20,
        curve: Curves.easeInOut,
      );
      final curvedProgress = transition.curvedProgressAt(10);
      // easeInOut at 0.5 should be 0.5
      expect(curvedProgress, closeTo(0.5, 0.01));
    });

    test('applies elasticOut curve', () {
      const transition = SceneTransition.scale(
        durationInFrames: 20,
        curve: Curves.elasticOut,
      );
      final curvedProgress = transition.curvedProgressAt(20);
      // At the end, should be 1.0 regardless of curve
      expect(curvedProgress, 1.0);
    });
  });

  group('edge cases', () {
    test('handles very short duration', () {
      const transition = SceneTransition.crossFade(durationInFrames: 1);
      expect(transition.progressAt(0), 0.0);
      expect(transition.progressAt(1), 1.0);
    });

    test('handles very long duration', () {
      const transition = SceneTransition.crossFade(durationInFrames: 1000);
      expect(transition.progressAt(500), 0.5);
    });

    test('different transitions can be compared', () {
      const t1 = SceneTransition.crossFade(durationInFrames: 15);
      const t2 = SceneTransition.slideLeft(durationInFrames: 15);

      expect(t1.type, isNot(equals(t2.type)));
      expect(t1.durationInFrames, equals(t2.durationInFrames));
    });
  });
}
