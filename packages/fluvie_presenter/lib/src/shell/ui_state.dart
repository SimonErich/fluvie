import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A boolean piece of chrome state (HUD, sidebar, notes) with a seedable
/// initial value — the shell seeds sidebar and notes from the `FluvieSlides`
/// flags by overriding the provider.
final class UiToggle extends Notifier<bool> {
  /// Creates the toggle starting at the given initial visibility.
  UiToggle(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;

  /// Flips the toggle.
  void toggle() => state = !state;

  /// Sets the toggle.
  set visible(bool value) => state = value;
}

/// Whether the slide counter and progress indicator are visible.
final hudVisibleProvider = NotifierProvider<UiToggle, bool>(() => UiToggle(true));

/// Whether the slide sidebar is open.
final sidebarVisibleProvider = NotifierProvider<UiToggle, bool>(() => UiToggle(false));

/// Whether the speaker-notes panel is open.
final notesVisibleProvider = NotifierProvider<UiToggle, bool>(() => UiToggle(false));

/// Whether the overview grid is open.
final overviewVisibleProvider = NotifierProvider<UiToggle, bool>(() => UiToggle(false));
