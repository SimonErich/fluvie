import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:obers_ui/obers_ui.dart';

/// The four action gates in the first project guide.
enum QuickStartStep {
  /// Import a source into the bin.
  importMedia,

  /// Place a source on the timeline.
  place,

  /// Mark a source range or trim a placed clip.
  trim,

  /// Finish an export successfully.
  export,

  /// All four actions are complete.
  complete,
}

/// Finds the next useful action from actual document state. An export gate is
/// supplied by the host only after an artifact has been produced. Undoing an
/// arrangement naturally returns to the relevant step; a timer never advances it.
QuickStartStep quickStartStep(EditorDocument document, {required bool exported}) {
  if (document.mediaEntries.isEmpty) return QuickStartStep.importMedia;
  var placed = false;
  var timeBased = false;
  var trimmed = document.mediaEntries.any(
    (entry) => entry.inFrames != null || entry.outFrames != null,
  );
  void visit(Object? value) {
    if (value is Map<String, Object?>) {
      if (value.containsKey('source')) {
        placed = true;
        timeBased =
            timeBased ||
            value['type'] == 'Clip' ||
            value['kind'] == 'music' ||
            value['kind'] == 'sound';
        trimmed = trimmed || value.containsKey('trim');
      }
      value.values.forEach(visit);
    } else if (value is List<Object?>) {
      value.forEach(visit);
    }
  }

  visit(document.toJson()..remove('editor'));
  if (!placed) return QuickStartStep.place;
  if (timeBased && !trimmed) return QuickStartStep.trim;
  return exported ? QuickStartStep.complete : QuickStartStep.export;
}

/// Non-modal, action-gated guidance. There is no Next button: the requested
/// action is the gate. Hosts may pair it with an input-transparent OiSpotlight.
final class QuickStartHint extends StatelessWidget {
  /// Shows the next step, or nothing once complete.
  const QuickStartHint({required this.step, required this.onDismiss, super.key});

  /// The next incomplete action.
  final QuickStartStep step;

  /// Remembers that the author dismissed the guide.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (step == QuickStartStep.complete) return const SizedBox.shrink();
    final label = switch (step) {
      QuickStartStep.importMedia => 'Import a video, image or audio file into Assets.',
      QuickStartStep.place =>
        'Select a source, mark its range, then choose Place or drag it to the timeline.',
      QuickStartStep.trim =>
        'Set In and Out in the source monitor, or drag a clip edge to trim it.',
      QuickStartStep.export => 'Open Export video and save your first render.',
      QuickStartStep.complete => '',
    };
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(child: OiLabel.small('Step ${step.index + 1} of 4 · $label')),
            OiButton.ghost(label: 'Dismiss guide', onTap: onDismiss),
          ],
        ),
      ),
    );
  }
}
