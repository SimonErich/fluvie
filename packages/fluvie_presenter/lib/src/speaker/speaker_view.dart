import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show Video;
import 'package:fluvie_presenter/src/controller/presentation_controller.dart';
import 'package:fluvie_presenter/src/notes/notes_compiler.dart';
import 'package:fluvie_presenter/src/speaker/speaker_next_preview.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt, OiLabel;

/// The speaker's own screen: the next state live, the current notes, the
/// highlight bullets down the right, plus the elapsed clock and where the
/// deck stands.
///
/// The view only reads the shared presentation scope — a sync binding keeps
/// that scope in lockstep with the presenting window.
final class SpeakerView extends ConsumerStatefulWidget {
  /// Creates the view for [video].
  const SpeakerView({required this.video, super.key});

  /// The authored deck.
  final Video video;

  @override
  ConsumerState<SpeakerView> createState() => _SpeakerViewState();
}

final class _SpeakerViewState extends ConsumerState<SpeakerView> {
  int _seconds = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // A wall clock in chrome is fine: nothing here is captured. Counting
    // ticks (not reading a Stopwatch) keeps the clock testable on the fake
    // test clock; a second of drift over a talk does not matter.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get _clock {
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final position = ref.watch(
      presentationControllerProvider.select((state) => state.position),
    );
    final plans = ref.watch(slidePlansProvider);
    final notes = ref.watch(slideNotesProvider)[position.slide][position.step];
    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      OiLabel.smallStrong(
                        'Slide ${position.slide + 1} / ${plans.length}',
                        color: colors.text,
                      ),
                      const SizedBox(width: 16),
                      OiLabel.small(_clock, color: colors.textSubtle),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OiLabel.small('Next', color: colors.textMuted),
                  const SizedBox(height: 4),
                  AspectRatio(
                    aspectRatio: widget.video.width / widget.video.height,
                    child: SpeakerNextPreview(video: widget.video),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: OiLabel.body(
                        notes.text ?? 'No notes for this slide.',
                        color: notes.text == null ? colors.textMuted : colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (notes.highlights.isNotEmpty) ...[
              const SizedBox(width: 24),
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final highlight in notes.highlights)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OiLabel.small('•  $highlight', color: colors.textSubtle),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
