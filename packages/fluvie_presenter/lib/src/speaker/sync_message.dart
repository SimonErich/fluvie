import 'package:fluvie_presenter/src/controller/presentation_position.dart';
import 'package:meta/meta.dart';

/// What the presenting window and the speaker window say to each other:
/// where the presentation stands, and requests to move it.
///
/// Messages are plain JSON maps on the wire ([toJson]/[SyncMessage.fromJson])
/// because
/// every transport — a web `BroadcastChannel`, a desktop window channel, a
/// test fake — clones values, never objects.
@immutable
sealed class SyncMessage {
  const SyncMessage();

  /// Decodes a message [json] produced by [toJson].
  ///
  /// Throws a [FormatException] for payloads no known message shape claims —
  /// a version-skewed peer fails loud, not silently.
  factory SyncMessage.fromJson(Map<String, Object?> json) => switch (json['type']) {
    'position' => PositionUpdate(
      PresentationPosition(json['slide']! as int, json['step']! as int),
    ),
    'navigate' => NavigationRequest._fromJson(json),
    _ => throw FormatException('Unknown sync message: $json'),
  };

  /// Encodes the message as a JSON-safe map.
  Map<String, Object?> toJson();
}

/// "The presentation now stands here" — broadcast after every local move so
/// the other window follows.
final class PositionUpdate extends SyncMessage {
  /// Creates the update for [position].
  const PositionUpdate(this.position);

  /// Where the sender's presentation stands.
  final PresentationPosition position;

  @override
  Map<String, Object?> toJson() => {
    'type': 'position',
    'slide': position.slide,
    'step': position.step,
  };

  @override
  bool operator ==(Object other) => other is PositionUpdate && other.position == position;

  @override
  int get hashCode => Object.hash(PositionUpdate, position);

  @override
  String toString() => 'PositionUpdate($position)';
}

/// How a [NavigationRequest] wants to move.
enum NavigationAction {
  /// One step forward.
  next,

  /// One position back.
  back,

  /// Land on [NavigationRequest.target].
  jump,
}

/// "Move the presentation" — either window may ask; the receiver applies it
/// through its own controller.
final class NavigationRequest extends SyncMessage {
  /// A forward advance.
  const NavigationRequest.next() : action = NavigationAction.next, target = null;

  /// One position back.
  const NavigationRequest.back() : action = NavigationAction.back, target = null;

  /// A jump to [target].
  const NavigationRequest.jump(PresentationPosition this.target) : action = NavigationAction.jump;

  factory NavigationRequest._fromJson(Map<String, Object?> json) => switch (json['action']) {
    'next' => const NavigationRequest.next(),
    'back' => const NavigationRequest.back(),
    'jump' when json['slide'] is int && json['step'] is int => NavigationRequest.jump(
      PresentationPosition(json['slide']! as int, json['step']! as int),
    ),
    _ => throw FormatException('Unknown navigation request: $json'),
  };

  /// The move being requested.
  final NavigationAction action;

  /// The jump target; `null` for next and back.
  final PresentationPosition? target;

  @override
  Map<String, Object?> toJson() => {
    'type': 'navigate',
    'action': action.name,
    if (target != null) 'slide': target!.slide,
    if (target != null) 'step': target!.step,
  };

  @override
  bool operator ==(Object other) =>
      other is NavigationRequest && other.action == action && other.target == target;

  @override
  int get hashCode => Object.hash(NavigationRequest, action, target);

  @override
  String toString() => 'NavigationRequest(${action.name}${target == null ? '' : ' $target'})';
}
