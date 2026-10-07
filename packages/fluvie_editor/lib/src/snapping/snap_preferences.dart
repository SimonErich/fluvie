import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The canvas aids a user can toggle: snapping (on by default), the rulers
/// (off by default; dragging from one places a manual guide), and the
/// optional grid.
@immutable
final class SnapPreferences {
  /// Creates the preference set.
  const SnapPreferences({this.snapping = true, this.rulers = false, this.gridSpacing});

  /// Whether drags snap at all (Ctrl bypasses per gesture).
  final bool snapping;

  /// Whether the rulers (and their guides' handles) are visible.
  final bool rulers;

  /// The grid step in canvas pixels, or null for no grid.
  final double? gridSpacing;

  @override
  bool operator ==(Object other) =>
      other is SnapPreferences &&
      other.snapping == snapping &&
      other.rulers == rulers &&
      other.gridSpacing == gridSpacing;

  @override
  int get hashCode => Object.hash(snapping, rulers, gridSpacing);

  @override
  String toString() => 'SnapPreferences(snapping: $snapping, rulers: $rulers, grid: $gridSpacing)';
}

/// The one state the canvas, the toolbar, and the shortcuts read and write.
final class SnapPreferencesController extends Notifier<SnapPreferences> {
  @override
  SnapPreferences build() => const SnapPreferences();

  /// Flips snapping on or off.
  void toggleSnapping() => state = SnapPreferences(
    snapping: !state.snapping,
    rulers: state.rulers,
    gridSpacing: state.gridSpacing,
  );

  /// Shows or hides the rulers.
  void toggleRulers() => state = SnapPreferences(
    snapping: state.snapping,
    rulers: !state.rulers,
    gridSpacing: state.gridSpacing,
  );

  /// Sets the grid step in canvas pixels (null turns the grid off).
  void setGridSpacing(double? spacing) => state = SnapPreferences(
    snapping: state.snapping,
    rulers: state.rulers,
    gridSpacing: spacing,
  );
}

/// The canvas-aid preferences.
final snapPreferencesProvider = NotifierProvider<SnapPreferencesController, SnapPreferences>(
  SnapPreferencesController.new,
);
