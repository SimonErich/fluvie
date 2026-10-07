import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show Video;
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/deck/deck_registry.dart';
import 'package:slides/start/samples_choice.dart';

/// Opens the samples dialog over [context] and resolves to what the user
/// picked, or null when the dialog is dismissed.
Future<SamplesChoice?> showSamplesDialog(BuildContext context) => OiDialogShell.show<SamplesChoice>(
  context: context,
  semanticLabel: 'Samples and tutorials',
  minWidth: 320,
  maxWidth: 720,
  maxHeight: 720,
  // The form variant, because eight tiles outgrow 620px: it is the one
  // that hands its content a scroll view instead of overflowing.
  builder: (close) => OiDialog.form(
    label: 'Samples and tutorials',
    title: 'Samples and tutorials',
    content: SamplesGalleryList(onPick: close),
    actions: [OiButton.secondary(label: 'Close', onTap: () => close())],
  ),
);

/// The samples dialog's body: every bundled deck to present, then the one
/// way into the editor's demo spec.
///
/// The sample decks live here and nowhere else on the start screen, so the
/// tutorials stay one click away without owning the studio's front door.
final class SamplesGalleryList extends StatelessWidget {
  /// Lists the bundled decks; a tap hands the choice to [onPick].
  const SamplesGalleryList({required this.onPick, super.key});

  /// Receives the picked sample.
  final void Function(SamplesChoice choice) onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OiLabel.small(
          'These decks ship with fluvie. Pick one to present it.',
          color: colors.textMuted,
        ),
        const SizedBox(height: 16),
        OiLabel.overline('PRESENT', color: colors.textMuted),
        const SizedBox(height: 4),
        for (final deck in bundledDecks)
          OiListTile(
            leading: _SampleThumb(deck: deck),
            title: deck.title,
            subtitle: deck.subtitle,
            dense: true,
            onTap: () => onPick(PresentSample(deck)),
          ),
        const SizedBox(height: 16),
        const OiDivider(),
        const SizedBox(height: 12),
        OiLabel.overline('OPEN IN THE EDITOR', color: colors.textMuted),
        const SizedBox(height: 4),
        OiListTile(
          // The same 64px lane the thumbnails occupy, so both sections'
          // titles start on one line.
          leading: SizedBox(
            width: 64,
            child: OiIcon.decorative(icon: OiIcons.pencil, size: 18, color: colors.textMuted),
          ),
          title: 'Edit the demo deck',
          subtitle: 'The bundled spec, opened on the canvas',
          dense: true,
          onTap: () => onPick(const EditDemoSample()),
        ),
      ],
    );
  }
}

/// The built decks behind the thumbnails, kept per deck id so reopening the
/// dialog never rebuilds seven videos.
final Map<String, ({Video video, List<SlidePlan> plans})> _samplePreviews = {};

/// A still of the deck's first slide, held on a paused clock so the dialog
/// never schedules a frame.
final class _SampleThumb extends StatelessWidget {
  const _SampleThumb({required this.deck});

  final DeckEntry deck;

  @override
  Widget build(BuildContext context) {
    final preview = _samplePreviews.putIfAbsent(deck.id, () {
      final video = deck.build();
      return (video: video, plans: compileSlidePlans(video));
    });
    return SizedBox(
      width: 64,
      height: 36,
      child: ClipRRect(
        borderRadius: context.radius.sm,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SlidePreviewFrame(video: preview.video, plan: preview.plans.first),
        ),
      ),
    );
  }
}
