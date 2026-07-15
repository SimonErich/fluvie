import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';

/// Carries the active [MediaResolver] down to the elements that paint media.
///
/// `Image`, `Clip`, and the media backgrounds read their pre-resolved bytes
/// and decoded images from this scope: the render shell mounts one (from
/// `mediaResolverProvider`) above the composition before the frame loop, so
/// paint is a synchronous lookup.
///
/// A live preview mounts one only if it opts in with a `PreviewMediaScope`
/// (which runs the same pre-pass first). With no scope, an `Image` falls back to
/// Flutter's async image path and a `Clip` — which has no async equivalent to
/// fall back to — paints its placeholder.
final class ImageResolverScope extends InheritedWidget {
  /// Provides [resolver] to every descendant of [child].
  const ImageResolverScope({required this.resolver, required super.child, super.key});

  /// The resolver that answers `resolvedFor`/`decodedImageFor` synchronously.
  final MediaResolver resolver;

  /// The resolver in scope above [context], or `null` when there is none
  /// (a live preview, not a capture).
  static MediaResolver? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ImageResolverScope>()?.resolver;

  /// The resolver in scope above [context]; throws a [FlutterError] when there
  /// is none, naming the missing scope.
  static MediaResolver of(BuildContext context) {
    final resolver = maybeOf(context);
    if (resolver == null) {
      throw FlutterError(
        'No ImageResolverScope found in context. A media element needs a '
        'resolver above it; the render shell mounts one before the frame loop.',
      );
    }
    return resolver;
  }

  @override
  bool updateShouldNotify(ImageResolverScope oldWidget) => !identical(oldWidget.resolver, resolver);
}
