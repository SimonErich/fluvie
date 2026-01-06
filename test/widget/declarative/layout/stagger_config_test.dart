import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/stagger_config.dart';

void main() {
  group('StaggerConfig', () {
    group('basic constructor', () {
      test('creates with required delay', () {
        const config = StaggerConfig(delay: 10);

        expect(config.delay, 10);
      });

      test('default values', () {
        const config = StaggerConfig(delay: 10);

        expect(config.duration, isNull);
        expect(config.curve, Curves.easeOut);
        expect(config.fadeIn, isTrue);
        expect(config.slideIn, isFalse);
        expect(config.slideOffset, const Offset(0, 30));
        expect(config.scaleIn, isFalse);
        expect(config.scaleStart, 0.8);
      });

      test('custom duration', () {
        const config = StaggerConfig(delay: 10, duration: 30);

        expect(config.duration, 30);
        expect(config.effectiveDuration, 30);
      });

      test('custom curve', () {
        const config = StaggerConfig(delay: 10, curve: Curves.bounceOut);

        expect(config.curve, Curves.bounceOut);
      });

      test('custom fadeIn', () {
        const config = StaggerConfig(delay: 10, fadeIn: false);

        expect(config.fadeIn, isFalse);
      });

      test('custom slideIn', () {
        const config = StaggerConfig(
          delay: 10,
          slideIn: true,
          slideOffset: Offset(50, 0),
        );

        expect(config.slideIn, isTrue);
        expect(config.slideOffset, const Offset(50, 0));
      });

      test('custom scaleIn', () {
        const config = StaggerConfig(
          delay: 10,
          scaleIn: true,
          scaleStart: 0.5,
        );

        expect(config.scaleIn, isTrue);
        expect(config.scaleStart, 0.5);
      });
    });

    group('factory constructors', () {
      group('StaggerConfig.fade', () {
        test('creates fade-only config', () {
          const config = StaggerConfig.fade(delay: 15);

          expect(config.delay, 15);
          expect(config.fadeIn, isTrue);
          expect(config.slideIn, isFalse);
          expect(config.scaleIn, isFalse);
        });

        test('with custom duration', () {
          const config = StaggerConfig.fade(delay: 15, duration: 25);

          expect(config.duration, 25);
        });

        test('with custom curve', () {
          const config = StaggerConfig.fade(delay: 15, curve: Curves.linear);

          expect(config.curve, Curves.linear);
        });
      });

      group('StaggerConfig.slideUp', () {
        test('creates slide-up config', () {
          final config = StaggerConfig.slideUp(delay: 10);

          expect(config.delay, 10);
          expect(config.fadeIn, isTrue);
          expect(config.slideIn, isTrue);
          expect(config.slideOffset.dx, 0);
          expect(config.slideOffset.dy, 30); // Default distance
        });

        test('with custom distance', () {
          final config = StaggerConfig.slideUp(delay: 10, distance: 50);

          expect(config.slideOffset, const Offset(0, 50));
        });

        test('with custom duration', () {
          final config = StaggerConfig.slideUp(delay: 10, duration: 40);

          expect(config.duration, 40);
        });
      });

      group('StaggerConfig.slideDown', () {
        test('creates slide-down config', () {
          final config = StaggerConfig.slideDown(delay: 10);

          expect(config.delay, 10);
          expect(config.fadeIn, isTrue);
          expect(config.slideIn, isTrue);
          expect(config.slideOffset.dx, 0);
          expect(config.slideOffset.dy, -30); // Negative for down
        });

        test('with custom distance', () {
          final config = StaggerConfig.slideDown(delay: 10, distance: 60);

          expect(config.slideOffset, const Offset(0, -60));
        });
      });

      group('StaggerConfig.slideLeft', () {
        test('creates slide-left config', () {
          final config = StaggerConfig.slideLeft(delay: 10);

          expect(config.delay, 10);
          expect(config.fadeIn, isTrue);
          expect(config.slideIn, isTrue);
          expect(config.slideOffset.dx, 30); // Positive for left
          expect(config.slideOffset.dy, 0);
        });

        test('with custom distance', () {
          final config = StaggerConfig.slideLeft(delay: 10, distance: 40);

          expect(config.slideOffset, const Offset(40, 0));
        });
      });

      group('StaggerConfig.slideRight', () {
        test('creates slide-right config', () {
          final config = StaggerConfig.slideRight(delay: 10);

          expect(config.delay, 10);
          expect(config.fadeIn, isTrue);
          expect(config.slideIn, isTrue);
          expect(config.slideOffset.dx, -30); // Negative for right
          expect(config.slideOffset.dy, 0);
        });

        test('with custom distance', () {
          final config = StaggerConfig.slideRight(delay: 10, distance: 45);

          expect(config.slideOffset, const Offset(-45, 0));
        });
      });

      group('StaggerConfig.scale', () {
        test('creates scale config', () {
          final config = StaggerConfig.scale(delay: 10);

          expect(config.delay, 10);
          expect(config.fadeIn, isTrue);
          expect(config.slideIn, isFalse);
          expect(config.scaleIn, isTrue);
          expect(config.scaleStart, 0.8); // Default start
        });

        test('with custom start scale', () {
          final config = StaggerConfig.scale(delay: 10, start: 0.3);

          expect(config.scaleStart, 0.3);
        });
      });

      group('StaggerConfig.slideUpScale', () {
        test('creates combined slide-up and scale config', () {
          final config = StaggerConfig.slideUpScale(delay: 10);

          expect(config.delay, 10);
          expect(config.fadeIn, isTrue);
          expect(config.slideIn, isTrue);
          expect(config.scaleIn, isTrue);
          expect(config.slideOffset.dy, 30);
          expect(config.scaleStart, 0.8);
        });

        test('with custom parameters', () {
          final config = StaggerConfig.slideUpScale(
            delay: 10,
            slideDistance: 50,
            scaleStart: 0.5,
          );

          expect(config.slideOffset, const Offset(0, 50));
          expect(config.scaleStart, 0.5);
        });
      });
    });

    group('effectiveDuration', () {
      test('returns duration when specified', () {
        const config = StaggerConfig(delay: 10, duration: 45);

        expect(config.effectiveDuration, 45);
      });

      test('returns default 20 when duration is null', () {
        const config = StaggerConfig(delay: 10);

        expect(config.effectiveDuration, 20);
      });
    });

    group('startFrameForIndex', () {
      test('calculates start frame for first child', () {
        const config = StaggerConfig(delay: 10);

        expect(config.startFrameForIndex(0), 0);
      });

      test('calculates start frame for second child', () {
        const config = StaggerConfig(delay: 10);

        expect(config.startFrameForIndex(1), 10);
      });

      test('calculates start frame for fifth child', () {
        const config = StaggerConfig(delay: 15);

        expect(config.startFrameForIndex(4), 60); // 4 * 15
      });

      test('respects base frame', () {
        const config = StaggerConfig(delay: 10);

        expect(config.startFrameForIndex(0, 30), 30);
        expect(config.startFrameForIndex(1, 30), 40);
        expect(config.startFrameForIndex(2, 30), 50);
      });
    });

    group('endFrameForIndex', () {
      test('calculates end frame for first child', () {
        const config = StaggerConfig(delay: 10, duration: 20);

        expect(config.endFrameForIndex(0), 20); // 0 + 20
      });

      test('calculates end frame for second child', () {
        const config = StaggerConfig(delay: 10, duration: 20);

        expect(config.endFrameForIndex(1), 30); // 10 + 20
      });

      test('uses effectiveDuration when duration is null', () {
        const config = StaggerConfig(delay: 10);

        expect(config.endFrameForIndex(0), 20); // 0 + 20 (default)
      });

      test('respects base frame', () {
        const config = StaggerConfig(delay: 10, duration: 15);

        expect(config.endFrameForIndex(0, 30), 45); // 30 + 15
        expect(config.endFrameForIndex(1, 30), 55); // 40 + 15
      });
    });

    group('totalDuration', () {
      test('returns 0 for 0 children', () {
        const config = StaggerConfig(delay: 10, duration: 20);

        expect(config.totalDuration(0), 0);
      });

      test('returns 0 for negative children', () {
        const config = StaggerConfig(delay: 10, duration: 20);

        expect(config.totalDuration(-1), 0);
      });

      test('returns duration for single child', () {
        const config = StaggerConfig(delay: 10, duration: 20);

        expect(config.totalDuration(1), 20); // Just the animation duration
      });

      test('calculates total for multiple children', () {
        const config = StaggerConfig(delay: 10, duration: 20);

        // 3 children: last starts at frame 20 (2 * 10), ends at 40 (20 + 20)
        expect(config.totalDuration(3), 40);
      });

      test('calculates total with larger delay', () {
        const config = StaggerConfig(delay: 30, duration: 15);

        // 4 children: last starts at frame 90 (3 * 30), ends at 105 (90 + 15)
        expect(config.totalDuration(4), 105);
      });

      test('uses effectiveDuration when duration is null', () {
        const config = StaggerConfig(delay: 10);

        // 2 children: last starts at frame 10 (1 * 10), ends at 30 (10 + 20 default)
        expect(config.totalDuration(2), 30);
      });
    });

    group('edge cases', () {
      test('handles zero delay', () {
        const config = StaggerConfig(delay: 0, duration: 20);

        expect(config.startFrameForIndex(0), 0);
        expect(config.startFrameForIndex(1), 0);
        expect(config.startFrameForIndex(5), 0);
        expect(config.totalDuration(5), 20); // All start and end at same time
      });

      test('handles very large delay', () {
        const config = StaggerConfig(delay: 1000, duration: 10);

        expect(config.startFrameForIndex(100), 100000);
        expect(config.endFrameForIndex(100), 100010);
      });

      test('handles very large duration', () {
        const config = StaggerConfig(delay: 10, duration: 10000);

        expect(config.effectiveDuration, 10000);
        expect(config.totalDuration(3), 10020); // 20 + 10000
      });

      test('handles zero scaleStart', () {
        final config = StaggerConfig.scale(delay: 10, start: 0.0);

        expect(config.scaleStart, 0.0);
      });

      test('handles scale greater than 1', () {
        final config = StaggerConfig.scale(delay: 10, start: 1.5);

        expect(config.scaleStart, 1.5);
      });

      test('handles negative slide distance', () {
        final config = StaggerConfig.slideUp(delay: 10, distance: -20);

        expect(config.slideOffset, const Offset(0, -20));
      });

      test('handles zero slide distance', () {
        final config = StaggerConfig.slideUp(delay: 10, distance: 0);

        expect(config.slideOffset, Offset.zero);
      });
    });
  });
}
