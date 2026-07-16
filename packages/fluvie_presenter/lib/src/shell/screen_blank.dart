import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which blanking screen covers the stage — the presenter's "look at me,
/// not the slides" mode.
enum BlankScreen {
  /// A full black cover (B, or the period presenter remotes send).
  black,

  /// A full white cover (W).
  white,
}

/// Holds the active blanking screen; pressing the same key again (or any
/// navigation) clears it.
final class BlankScreenNotifier extends Notifier<BlankScreen?> {
  @override
  BlankScreen? build() => null;

  /// Toggles [screen]: activating it, swapping from the other one, or
  /// clearing it when it is already up.
  void toggle(BlankScreen screen) => state = state == screen ? null : screen;

  /// Clears any active blanking screen.
  void clear() => state = null;
}

/// The active blanking screen, or `null` for none.
final blankScreenProvider = NotifierProvider<BlankScreenNotifier, BlankScreen?>(
  BlankScreenNotifier.new,
);

/// Covers the stage with the active blanking color; renders nothing when no
/// blank is up. The position underneath holds — clearing the blank shows
/// exactly what was there.
final class ScreenBlankOverlay extends ConsumerWidget {
  /// Creates the overlay.
  const ScreenBlankOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(blankScreenProvider)) {
    null => const SizedBox.shrink(),
    BlankScreen.black => const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
    BlankScreen.white => const ColoredBox(color: Color(0xFFFFFFFF), child: SizedBox.expand()),
  };
}
