import 'package:flutter/widgets.dart';

import '../../declarative/core/scene.dart';
import '../../declarative/core/scene_transition.dart';
import 'template_config.dart';
import 'template_data.dart';

/// Category of template for organization and discovery.
enum TemplateCategory {
  /// Intro/identity templates (TheNeonGate, DigitalMirror, etc.)
  intro,

  /// Ranking/list templates (StackClimb, SlotMachine, etc.)
  ranking,

  /// Data visualization templates (TheGrowthTree, OrbitalMetrics, etc.)
  dataViz,

  /// Collage/grid templates (TheGridShuffle, MosaicReveal, etc.)
  collage,

  /// Thematic/vibe templates (LofiWindow, GlitchReality, etc.)
  thematic,

  /// Conclusion/share templates (TheSummaryPoster, ParticleFarewell, etc.)
  conclusion,
}

/// Base class for all Spotify Wrapped-style templates.
///
/// Templates are pre-built scene compositions with customizable data,
/// colors, fonts, and timing. They follow a standardized data contract
/// to ensure consistency across the library.
///
/// Example:
/// ```dart
/// TheNeonGate(
///   data: IntroData(
///     title: 'Your 2024',
///     subtitle: 'Wrapped',
///     year: 2024,
///   ),
///   theme: TemplateTheme.neon,
///   timing: TemplateTiming.dramatic,
/// )
/// ```
///
/// To use a template in a video composition:
/// ```dart
/// Video(
///   fps: 30,
///   width: 1080,
///   height: 1920,
///   scenes: [
///     TheNeonGate(data: introData).toScene(),
///     StackClimb(data: rankingData).toScene(),
///   ],
/// )
/// ```
abstract class WrappedTemplate extends StatelessWidget {
  /// The data to display in this template.
  final TemplateData data;

  /// Optional theme overrides.
  final TemplateTheme? theme;

  /// Optional timing configuration.
  final TemplateTiming? timing;

  const WrappedTemplate({
    super.key,
    required this.data,
    this.theme,
    this.timing,
  });

  /// The recommended scene length in frames for this template.
  int get recommendedLength;

  /// The category of this template for organization.
  TemplateCategory get category;

  /// A short description of this template.
  String get description;

  /// Returns the default theme for this template.
  TemplateTheme get defaultTheme => TemplateTheme.spotify;

  /// Returns the default timing for this template.
  TemplateTiming get defaultTiming => TemplateTiming.standard;

  /// The effective theme (provided theme merged with defaults).
  TemplateTheme get effectiveTheme =>
      theme != null ? theme!.merge(defaultTheme) : defaultTheme;

  /// The effective timing (provided timing or defaults).
  TemplateTiming get effectiveTiming => timing ?? defaultTiming;

  /// Returns the list of assets required by this template.
  ///
  /// Override in subclasses to specify required assets.
  List<String> get requiredAssets => [];

  /// Builds the template as a [Scene] for use in a [Video].
  ///
  /// Parameters:
  /// - [durationInFrames]: Override the scene duration (defaults to [recommendedLength])
  /// - [transitionIn]: Custom transition entering this scene
  /// - [transitionOut]: Custom transition exiting this scene
  /// - [fadeInFrames]: Fade in duration (defaults to 0)
  /// - [fadeOutFrames]: Fade out duration (defaults to 0)
  Scene toScene({
    int? durationInFrames,
    SceneTransition? transitionIn,
    SceneTransition? transitionOut,
    int? fadeInFrames,
    int? fadeOutFrames,
  }) {
    return Scene(
      durationInFrames: durationInFrames ?? recommendedLength,
      transitionIn: transitionIn,
      transitionOut: transitionOut,
      fadeInFrames: fadeInFrames ?? 0,
      fadeOutFrames: fadeOutFrames ?? 0,
      children: [RepaintBoundary(child: this)],
    );
  }

  /// Builds a list of scenes from this template.
  ///
  /// Some templates may generate multiple scenes (e.g., intro + content).
  /// Override in subclasses that need multi-scene output.
  List<Scene> toScenes() => [toScene()];
}

/// Mixin providing common animation helpers for templates.
mixin TemplateAnimationMixin on WrappedTemplate {
  /// Calculates entry progress for an element.
  ///
  /// Returns 0.0 at [startFrame], 1.0 at [startFrame] + [duration].
  double calculateEntryProgress(
    int currentFrame,
    int startFrame,
    int duration, [
    Curve curve = Curves.easeOutCubic,
  ]) {
    if (currentFrame < startFrame) return 0.0;
    if (currentFrame >= startFrame + duration) return 1.0;

    final progress = (currentFrame - startFrame) / duration;
    return curve.transform(progress.clamp(0.0, 1.0));
  }

  /// Calculates exit progress for an element.
  ///
  /// Returns 0.0 before [exitStart], 1.0 at [exitStart] + [duration].
  double calculateExitProgress(
    int currentFrame,
    int exitStart,
    int duration, [
    Curve curve = Curves.easeInCubic,
  ]) {
    if (currentFrame < exitStart) return 0.0;
    if (currentFrame >= exitStart + duration) return 1.0;

    final progress = (currentFrame - exitStart) / duration;
    return curve.transform(progress.clamp(0.0, 1.0));
  }

  /// Calculates combined opacity from entry and exit progress.
  double calculateOpacity(double entryProgress, double exitProgress) {
    return (entryProgress * (1.0 - exitProgress)).clamp(0.0, 1.0);
  }

  /// Calculates staggered start frame for an element at [index].
  int staggeredStartFrame(int baseStart, int index) {
    return baseStart + (index * effectiveTiming.staggerDelay);
  }
}

/// Helper extension for easier template usage.
extension WrappedTemplateExtension on WrappedTemplate {
  /// Creates a Scene with cross-fade transition.
  Scene toSceneWithCrossFade({int? durationInFrames, int fadeDuration = 15}) {
    return toScene(
      durationInFrames: durationInFrames,
      transitionIn: SceneTransition.crossFade(durationInFrames: fadeDuration),
      transitionOut: SceneTransition.crossFade(durationInFrames: fadeDuration),
    );
  }

  /// Creates a Scene with slide transition.
  Scene toSceneWithSlide({
    int? durationInFrames,
    TransitionSlideDirection direction = TransitionSlideDirection.left,
    int slideDuration = 20,
  }) {
    SceneTransition transition;
    switch (direction) {
      case TransitionSlideDirection.left:
        transition = SceneTransition.slideLeft(durationInFrames: slideDuration);
      case TransitionSlideDirection.right:
        transition = SceneTransition.slideRight(
          durationInFrames: slideDuration,
        );
      case TransitionSlideDirection.up:
        transition = SceneTransition.slideUp(durationInFrames: slideDuration);
      case TransitionSlideDirection.down:
        transition = SceneTransition.slideDown(durationInFrames: slideDuration);
    }

    return toScene(
      durationInFrames: durationInFrames,
      transitionIn: transition,
    );
  }
}

/// Slide direction for template transitions.
enum TransitionSlideDirection { left, right, up, down }
