/// Animation library for Spotify Wrapped-style effects.
///
/// This library provides three categories of animations:
///
/// ## Core Animations
/// Building blocks for property-based animations.
/// Use [AnimatedProp], [PropAnimation], [Stagger], and [SlideIn].
///
/// ```dart
/// AnimatedProp(
///   animation: PropAnimation.fadeIn(),
///   duration: 30,
///   child: MyWidget(),
/// )
/// ```
///
/// ## Entry Animations
/// Animations for revealing elements with visual impact.
/// Use with [AnimatedProp] for frame-based control.
///
/// ```dart
/// AnimatedProp(
///   animation: EntryAnimation.elasticPop(),
///   duration: 45,
///   child: MyWidget(),
/// )
/// ```
///
/// ## Ambient Animations
/// Continuous motion effects for keeping elements alive.
/// Use as widget wrappers for constant motion.
///
/// ```dart
/// FloatingVibe(
///   amplitude: 15,
///   frequency: 0.3,
///   child: MyWidget(),
/// )
/// ```
library;

// Core animation building blocks
export 'core/core.dart';

// Entry animations (reveals, pops, etc.)
export 'entry/entry_animations.dart';

// Ambient animations (floating, pulsing, etc.)
export 'ambient/ambient_animations.dart';
