import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';

/// A concrete test implementation of WrappedTemplate for testing base behavior.
class TestTemplate extends WrappedTemplate {
  const TestTemplate({
    super.key,
    required super.data,
    super.theme,
    super.timing,
  });

  @override
  int get recommendedLength => 100;

  @override
  TemplateCategory get category => TemplateCategory.intro;

  @override
  String get description => 'Test template';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: effectiveTheme.backgroundColor,
      child: Center(
        child: Text(
          (data as IntroData).title,
          style: TextStyle(color: effectiveTheme.textColor),
        ),
      ),
    );
  }
}

class TestTemplateWithMixin extends WrappedTemplate with TemplateAnimationMixin {
  const TestTemplateWithMixin({
    super.key,
    required super.data,
    super.theme,
    super.timing,
  });

  @override
  int get recommendedLength => 100;

  @override
  TemplateCategory get category => TemplateCategory.intro;

  @override
  String get description => 'Test template with mixin';

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('WrappedTemplate', () {
    group('TemplateCategory', () {
      test('has all expected categories', () {
        expect(TemplateCategory.values, hasLength(6));
        expect(TemplateCategory.values, contains(TemplateCategory.intro));
        expect(TemplateCategory.values, contains(TemplateCategory.ranking));
        expect(TemplateCategory.values, contains(TemplateCategory.dataViz));
        expect(TemplateCategory.values, contains(TemplateCategory.collage));
        expect(TemplateCategory.values, contains(TemplateCategory.thematic));
        expect(TemplateCategory.values, contains(TemplateCategory.conclusion));
      });
    });

    group('construction', () {
      test('creates with required data', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);

        expect(template.data, data);
        expect(template.theme, isNull);
        expect(template.timing, isNull);
      });

      test('accepts optional theme', () {
        const data = IntroData(title: 'Test');
        final theme = TemplateTheme.neon;
        final template = TestTemplate(data: data, theme: theme);

        expect(template.theme, theme);
      });

      test('accepts optional timing', () {
        const data = IntroData(title: 'Test');
        const timing = TemplateTiming.quick;
        const template = TestTemplate(data: data, timing: timing);

        expect(template.timing, timing);
      });
    });

    group('abstract properties', () {
      test('recommendedLength returns correct value', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);

        expect(template.recommendedLength, 100);
      });

      test('category returns correct value', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);

        expect(template.category, TemplateCategory.intro);
      });

      test('description returns correct value', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);

        expect(template.description, 'Test template');
      });
    });

    group('default theme and timing', () {
      test('defaultTheme returns spotify theme', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);

        expect(template.defaultTheme, TemplateTheme.spotify);
      });

      test('defaultTiming returns standard timing', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);

        expect(template.defaultTiming, TemplateTiming.standard);
      });
    });

    group('effectiveTheme', () {
      test('returns default theme when no theme provided', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);

        expect(template.effectiveTheme, template.defaultTheme);
      });

      test('merges provided theme with default', () {
        const data = IntroData(title: 'Test');
        final customTheme = TemplateTheme.neon;
        final template = TestTemplate(data: data, theme: customTheme);

        expect(template.effectiveTheme, isNotNull);
      });
    });

    group('effectiveTiming', () {
      test('returns default timing when no timing provided', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);

        expect(template.effectiveTiming, template.defaultTiming);
      });

      test('returns provided timing when specified', () {
        const data = IntroData(title: 'Test');
        const timing = TemplateTiming.quick;
        const template = TestTemplate(data: data, timing: timing);

        expect(template.effectiveTiming, timing);
      });
    });

    group('requiredAssets', () {
      test('returns empty list by default', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);

        expect(template.requiredAssets, isEmpty);
      });
    });

    group('toScene', () {
      test('creates scene with recommended length', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);
        final scene = template.toScene();

        expect(scene.durationInFrames, 100);
      });

      test('creates scene with custom duration', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);
        final scene = template.toScene(durationInFrames: 200);

        expect(scene.durationInFrames, 200);
      });

      test('creates scene with fade frames', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);
        final scene = template.toScene(fadeInFrames: 10, fadeOutFrames: 15);

        expect(scene.fadeInFrames, 10);
        expect(scene.fadeOutFrames, 15);
      });

      test('creates scene with children containing template', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);
        final scene = template.toScene();

        expect(scene.children, isNotEmpty);
        expect(scene.children.first, isA<RepaintBoundary>());
      });
    });

    group('toScenes', () {
      test('returns single scene list by default', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);
        final scenes = template.toScenes();

        expect(scenes, hasLength(1));
      });
    });
  });

  group('TemplateAnimationMixin', () {
    group('calculateEntryProgress', () {
      test('returns 0 before start frame', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplateWithMixin(data: data);

        expect(template.calculateEntryProgress(0, 10, 20), 0.0);
        expect(template.calculateEntryProgress(5, 10, 20), 0.0);
        expect(template.calculateEntryProgress(9, 10, 20), 0.0);
      });

      test('returns 1 after duration', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplateWithMixin(data: data);

        expect(template.calculateEntryProgress(30, 10, 20), 1.0);
        expect(template.calculateEntryProgress(50, 10, 20), 1.0);
      });

      test('returns intermediate progress during animation', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplateWithMixin(data: data);

        final progress = template.calculateEntryProgress(20, 10, 20);
        expect(progress, greaterThan(0.0));
        expect(progress, lessThan(1.0));
      });

      test('applies curve to progress', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplateWithMixin(data: data);

        // Linear midpoint
        final linear = template.calculateEntryProgress(
          20,
          10,
          20,
          Curves.linear,
        );
        expect(linear, closeTo(0.5, 0.01));

        // Ease out should be ahead at midpoint
        final easeOut = template.calculateEntryProgress(
          20,
          10,
          20,
          Curves.easeOutCubic,
        );
        expect(easeOut, greaterThan(0.5));
      });
    });

    group('calculateExitProgress', () {
      test('returns 0 before exit start', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplateWithMixin(data: data);

        expect(template.calculateExitProgress(0, 50, 20), 0.0);
        expect(template.calculateExitProgress(49, 50, 20), 0.0);
      });

      test('returns 1 after duration', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplateWithMixin(data: data);

        expect(template.calculateExitProgress(70, 50, 20), 1.0);
        expect(template.calculateExitProgress(100, 50, 20), 1.0);
      });
    });

    group('calculateOpacity', () {
      test('returns 1 when fully entered and not exiting', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplateWithMixin(data: data);

        expect(template.calculateOpacity(1.0, 0.0), 1.0);
      });

      test('returns 0 when not entered', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplateWithMixin(data: data);

        expect(template.calculateOpacity(0.0, 0.0), 0.0);
      });

      test('returns 0 when fully exited', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplateWithMixin(data: data);

        expect(template.calculateOpacity(1.0, 1.0), 0.0);
      });

      test('returns intermediate value during animation', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplateWithMixin(data: data);

        expect(template.calculateOpacity(0.5, 0.0), 0.5);
        expect(template.calculateOpacity(1.0, 0.5), 0.5);
      });
    });

    group('staggeredStartFrame', () {
      test('returns base start for index 0', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplateWithMixin(data: data);

        expect(template.staggeredStartFrame(10, 0), 10);
      });

      test('adds stagger delay for each index', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplateWithMixin(data: data);
        final delay = template.effectiveTiming.staggerDelay;

        expect(template.staggeredStartFrame(10, 1), 10 + delay);
        expect(template.staggeredStartFrame(10, 2), 10 + (2 * delay));
        expect(template.staggeredStartFrame(10, 5), 10 + (5 * delay));
      });
    });
  });

  group('WrappedTemplateExtension', () {
    group('toSceneWithCrossFade', () {
      test('creates scene with cross-fade transitions', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });

      test('accepts custom fade duration', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);
        final scene = template.toSceneWithCrossFade(fadeDuration: 30);

        expect(scene.transitionIn, isNotNull);
      });

      test('accepts custom scene duration', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);
        final scene = template.toSceneWithCrossFade(durationInFrames: 200);

        expect(scene.durationInFrames, 200);
      });
    });

    group('toSceneWithSlide', () {
      test('creates scene with slide left transition', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);
        final scene = template.toSceneWithSlide();

        expect(scene.transitionIn, isNotNull);
      });

      test('creates scene with slide right transition', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);
        final scene = template.toSceneWithSlide(
          direction: TransitionSlideDirection.right,
        );

        expect(scene.transitionIn, isNotNull);
      });

      test('creates scene with slide up transition', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);
        final scene = template.toSceneWithSlide(
          direction: TransitionSlideDirection.up,
        );

        expect(scene.transitionIn, isNotNull);
      });

      test('creates scene with slide down transition', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);
        final scene = template.toSceneWithSlide(
          direction: TransitionSlideDirection.down,
        );

        expect(scene.transitionIn, isNotNull);
      });

      test('accepts custom slide duration', () {
        const data = IntroData(title: 'Test');
        const template = TestTemplate(data: data);
        final scene = template.toSceneWithSlide(slideDuration: 40);

        expect(scene.transitionIn, isNotNull);
      });
    });
  });

  group('TransitionSlideDirection', () {
    test('has all expected directions', () {
      expect(TransitionSlideDirection.values, hasLength(4));
      expect(TransitionSlideDirection.values, contains(TransitionSlideDirection.left));
      expect(TransitionSlideDirection.values, contains(TransitionSlideDirection.right));
      expect(TransitionSlideDirection.values, contains(TransitionSlideDirection.up));
      expect(TransitionSlideDirection.values, contains(TransitionSlideDirection.down));
    });
  });
}
