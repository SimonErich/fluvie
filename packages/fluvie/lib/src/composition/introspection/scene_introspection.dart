import 'package:fluvie/src/composition/introspection/element_introspection.dart';
import 'package:fluvie/src/composition/introspection/frame_span.dart';
import 'package:meta/meta.dart';

/// One scene on the resolved timeline: its absolute frame [span] and the
/// elements declared inside it, in walk order.
@immutable
final class SceneIntrospection {
  /// Creates the introspection of one scene.
  const SceneIntrospection({required this.index, required this.span, required this.elements});

  /// The scene's position in the video's scene list.
  final int index;

  /// The absolute frames the scene occupies. An overlapping transition
  /// starts a scene before its predecessor's span ends.
  final FrameSpan span;

  /// The scene's animated elements in walk (declaration) order.
  final List<ElementIntrospection> elements;

  @override
  String toString() => 'SceneIntrospection($index, $span, elements: ${elements.length})';
}
