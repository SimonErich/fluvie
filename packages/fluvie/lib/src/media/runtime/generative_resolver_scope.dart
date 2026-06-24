import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart';

/// Carries the active [GenerativeResolver] down to the generic generative
/// elements so they can map a `GenerativeSource` to its produced
/// `MediaSource`/`AudioSource` synchronously during the frame loop.
///
/// The render shell mounts one (from `generativeResolverProvider`) above the
/// composition before the frame loop, after [GenerativeResolver.generateAll] has
/// run. In a live preview app there is no scope and the elements paint a
/// placeholder instead.
///
/// `GenerativeMedia` and `generativeResolverProvider` are named in prose, not as
/// doc links, because they live in other layers.
final class GenerativeResolverScope extends InheritedWidget {
  /// Provides [resolver] to every descendant of [child].
  const GenerativeResolverScope({required this.resolver, required super.child, super.key});

  /// The resolver that answers `mediaFor`/`audioFor`/`metaFor` synchronously.
  final GenerativeResolver resolver;

  /// The resolver in scope above [context], or `null` when there is none
  /// (a live preview, not a capture).
  static GenerativeResolver? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GenerativeResolverScope>()?.resolver;

  @override
  bool updateShouldNotify(GenerativeResolverScope oldWidget) =>
      !identical(oldWidget.resolver, resolver);
}
