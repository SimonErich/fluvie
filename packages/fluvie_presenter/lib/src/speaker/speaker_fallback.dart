import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt, OiLabel, OiSurface;

/// Holds the speaker-window fallback instruction while it is on screen, or
/// `null` when it is not.
final class SpeakerFallbackNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Shows the instruction, with the [url] to open when the platform knows
  /// one.
  void show({String? url}) => state = url == null
      ? 'This platform cannot open a second window. Open the presentation '
            'in another window and press S there.'
      : 'Open this link in a second window: $url';

  /// Hides the instruction.
  void clear() => state = null;
}

/// The active speaker fallback message, or `null` for none.
final speakerFallbackProvider = NotifierProvider<SpeakerFallbackNotifier, String?>(
  SpeakerFallbackNotifier.new,
);

/// The card telling the user how to open the speaker view when no window
/// could open. Navigation and Esc clear it like every overlay.
final class SpeakerFallbackNotice extends ConsumerWidget {
  /// Creates the notice.
  const SpeakerFallbackNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(speakerFallbackProvider);
    if (message == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: OiSurface(
          color: context.colors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: OiLabel.small(message, color: context.colors.text),
        ),
      ),
    );
  }
}
