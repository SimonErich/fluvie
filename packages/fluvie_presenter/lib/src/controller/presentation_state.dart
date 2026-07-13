import 'package:fluvie_presenter/src/controller/navigation_kind.dart';
import 'package:fluvie_presenter/src/controller/presentation_position.dart';
import 'package:meta/meta.dart';

/// The presentation's navigable state: where it stands and how it got there.
///
/// [lastMove] is the playback-relevant half: a [NavigationKind.forward] move
/// plays the step's authored entrance, a [NavigationKind.instant] one lands
/// on the settled state. The slide view renders both from this one value.
@immutable
final class PresentationState {
  /// Creates the state at [position], reached by [lastMove].
  const PresentationState({required this.position, required this.lastMove});

  /// Where the presentation stands.
  final PresentationPosition position;

  /// How [position] was reached.
  final NavigationKind lastMove;

  @override
  bool operator ==(Object other) =>
      other is PresentationState && other.position == position && other.lastMove == lastMove;

  @override
  int get hashCode => Object.hash(PresentationState, position, lastMove);

  @override
  String toString() => 'PresentationState($position, ${lastMove.name})';
}
