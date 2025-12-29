/// Core animation system for declarative video composition.
///
/// Provides [PropAnimation] for defining animations, [AnimatedProp] for
/// applying animations to individual widgets, [Stagger] for cascading
/// animations across multiple children, [SlideIn]/[StaggeredSlideIn]
/// for directional entry animations, and [AnimationContext] for
/// parent-child timing coordination.
library;

export 'animated_positioned.dart';
export 'animated_prop.dart';
export 'animation_context.dart';
export 'positioned_animation.dart';
export 'prop_animation.dart';
export 'slide_in.dart';
export 'stagger.dart';
