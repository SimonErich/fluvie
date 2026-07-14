import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A boolean piece of chrome state (HUD, sidebar, notes) with a seedable
/// initial value — the shell seeds sidebar and notes from the `FluvieSlides`
/// flags by overriding the provider.
final class UiToggle extends Notifier<bool> {
  /// Creates the toggle starting at the given initial visibility.
  UiToggle({required bool initiallyVisible}) : _initial = initiallyVisible;

  final bool _initial;

  @override
  bool build() => _initial;

  /// Whether the toggle is on (the notifier state, readable off-tree).
  bool get visible => state;

  /// Sets the toggle.
  set visible(bool value) => state = value;

  /// Flips the toggle.
  void toggle() => state = !state;
}

/// Whether the slide counter and progress indicator are visible.
final hudVisibleProvider = NotifierProvider<UiToggle, bool>(
  () => UiToggle(initiallyVisible: true),
);

/// Whether the slide sidebar is open.
final sidebarVisibleProvider = NotifierProvider<UiToggle, bool>(
  () => UiToggle(initiallyVisible: false),
);

/// Whether the speaker-notes panel is open.
final notesVisibleProvider = NotifierProvider<UiToggle, bool>(
  () => UiToggle(initiallyVisible: false),
);

/// Whether the overview grid is open.
final overviewVisibleProvider = NotifierProvider<UiToggle, bool>(
  () => UiToggle(initiallyVisible: false),
);

/// Whether the presenter believes it is fullscreen — tracked from its own
/// enter/exit transitions (a native escape the page never sees can lag it).
/// The HUD strip auto-hides while this is on.
final fullscreenActiveProvider = NotifierProvider<UiToggle, bool>(
  () => UiToggle(initiallyVisible: false),
);
