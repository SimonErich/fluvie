import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show FrameSpan, decodeTime;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/video_mode/selected_audio.dart';
import 'package:fluvie_editor/src/video_mode/video_timebase.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

part 'audio_track_section_fields.dart';

/// The audio inspector: the selected audio lane's volume, fades, loop,
/// trim, and start — plus reorder within the mix and removal — every edit
/// one undoable command over the owner's `audio` list.
final class AudioTrackSection extends ConsumerWidget {
  /// Inspects [selection] of [document]; commands land in [onCommand].
  const AudioTrackSection({
    required this.document,
    required this.selection,
    required this.timebase,
    required this.onCommand,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The selected audio track.
  final SelectedAudioTrack selection;

  /// The whole-video clock reference (how authored times resolve to
  /// frames).
  final VideoTimebase timebase;

  /// Receives every dispatched command.
  final void Function(EditorCommand command) onCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = document.audioTracksJson(scene: selection.scene);
    if (selection.index >= tracks.length) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: OiLabel.body('Nothing here anymore', color: context.colors.textSubtle),
      );
    }
    final json = tracks[selection.index];
    final scene = selection.scene;
    final owner = scene == null ? FrameSpan(0, timebase.totalFrames) : timebase.sceneSpans[scene];
    final fields = _AudioFields(
      json: json,
      scope: OwnerFrameScope(timebase.fps, owner),
      patch: (patch) => onCommand(
        SetAudioTrackCommand(scene: selection.scene, index: selection.index, patch: patch),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(context, ref, json, tracks.length),
        OiPropertyGrid(properties: fields.rows()),
        if (fields.triggerNote case final String note)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: OiLabel.small(note, color: context.colors.textSubtle),
          ),
      ],
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, Map<String, Object?> json, int count) {
    final source = json['source']! as Map<String, Object?>;
    final name = (source['value']! as String).split('/').last;
    return Row(
      children: [
        Expanded(child: OiLabel.small(name, color: context.colors.text)),
        OiLabel.small(json['kind']! as String, color: context.colors.textSubtle),
        const SizedBox(width: 4),
        EditorTip(
          message: 'Move up in the mix',
          child: OiIconButton(
            icon: OiIcons.arrowUp,
            semanticLabel: 'Move up in the mix',
            size: OiButtonSize.small,
            onTap: selection.index == 0 ? null : () => _reorder(ref, -1),
          ),
        ),
        EditorTip(
          message: 'Move down in the mix',
          child: OiIconButton(
            icon: OiIcons.arrowDown,
            semanticLabel: 'Move down in the mix',
            size: OiButtonSize.small,
            onTap: selection.index >= count - 1 ? null : () => _reorder(ref, 1),
          ),
        ),
        EditorTip(
          message: 'Remove track',
          child: OiIconButton(
            icon: OiIcons.trash,
            semanticLabel: 'Remove track',
            size: OiButtonSize.small,
            onTap: () {
              ref.read(audioSelectionProvider.notifier).clear();
              onCommand(RemoveAudioTrackCommand(scene: selection.scene, index: selection.index));
            },
          ),
        ),
      ],
    );
  }

  /// Moves the track by [delta] in the mix order; the selection follows it.
  void _reorder(WidgetRef ref, int delta) {
    final to = selection.index + delta;
    ref
        .read(audioSelectionProvider.notifier)
        .select(SelectedAudioTrack(scene: selection.scene, index: to));
    onCommand(
      ReorderAudioTrackCommand(scene: selection.scene, from: selection.index, to: to),
    );
  }
}
