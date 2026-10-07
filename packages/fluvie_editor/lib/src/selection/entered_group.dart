import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which group the user has entered by double-click, or null at the top
/// level.
///
/// While a group is entered, hit-testing, the gizmo, and the layer commands
/// operate on that group's children (their transforms are group-relative);
/// Escape and clicks outside the group exit. E15's one-unit rule applies
/// only outside the entered group.
final class EnteredGroupController extends Notifier<String?> {
  @override
  String? build() => null;

  /// Enters group [id] — selection now works within its children.
  // ignore: use_setters_to_change_properties, enter/exit are paired commands like the tool controller's apply; a setter would read as assignment.
  void enter(String id) => state = id;

  /// Back to the top level.
  void exit() => state = null;
}

/// The entered group for the mounted editor scope.
final enteredGroupProvider = NotifierProvider<EnteredGroupController, String?>(
  EnteredGroupController.new,
);
