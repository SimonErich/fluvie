part of 'presentation_shortcuts.dart';

/// What the presenter's inputs do — one callback per user intention, so the
/// input layer stays a dumb map and tests record calls instead of pumping
/// the whole shell.
final class PresenterHandlers {
  /// Creates the handler set; every intention must be wired.
  const PresenterHandlers({
    required this.onNext,
    required this.onBack,
    required this.onFirst,
    required this.onLast,
    required this.onJump,
    required this.onToggleFullscreen,
    required this.onEscape,
    required this.onOverview,
    required this.onSpeakerWindow,
    required this.onBlackScreen,
    required this.onWhiteScreen,
    required this.onToggleHud,
    required this.onToggleSidebar,
    required this.onToggleNotes,
    this.onClose,
  });

  /// Advance one step (or onto the next slide).
  final VoidCallback onNext;

  /// Go back one position, landing on its held state.
  final VoidCallback onBack;

  /// Jump to the first slide.
  final VoidCallback onFirst;

  /// Jump to the last slide.
  final VoidCallback onLast;

  /// Jump to a slide by zero-based index (typed digits are one-based).
  final void Function(int slide) onJump;

  /// Toggle fullscreen (F, and the F5 presenter remotes send).
  final VoidCallback onToggleFullscreen;

  /// Escape: close the topmost overlay, else leave fullscreen.
  final VoidCallback onEscape;

  /// Toggle the overview grid.
  final VoidCallback onOverview;

  /// Open (or focus) the speaker window.
  final VoidCallback onSpeakerWindow;

  /// Toggle the black screen (B, and the period remotes send).
  final VoidCallback onBlackScreen;

  /// Toggle the white screen.
  final VoidCallback onWhiteScreen;

  /// Toggle the slide counter and progress HUD.
  final VoidCallback onToggleHud;

  /// Toggle the slide sidebar (T, for thumbnails).
  final VoidCallback onToggleSidebar;

  /// Toggle the speaker-notes panel (N).
  final VoidCallback onToggleNotes;

  /// Ends the presentation (the host app's intention, so it is the one
  /// optional entry: without it the chrome shows no close button).
  final VoidCallback? onClose;
}
