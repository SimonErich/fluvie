import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_editor/src/selection/selection_controller.dart';
import 'package:meta/meta.dart';

/// One selected audio track: which `audio` list ([scene] null for the
/// video-level one) and the track's index in it.
@immutable
final class SelectedAudioTrack {
  /// Creates the selection.
  const SelectedAudioTrack({required this.scene, required this.index});

  /// The owning scene, or null for the video-level list.
  final int? scene;

  /// The track's position in its owner's `audio` list.
  final int index;

  @override
  bool operator ==(Object other) =>
      other is SelectedAudioTrack && other.scene == scene && other.index == index;

  @override
  int get hashCode => Object.hash(SelectedAudioTrack, scene, index);

  @override
  String toString() =>
      'SelectedAudioTrack(${scene == null ? 'video' : 'scene $scene'}, track $index)';
}

/// The selected audio lane, or null — video-timeline lane taps write here;
/// the lane highlight and the audio inspector watch it.
///
/// Selecting elements deselects audio (one selected thing at a time, the
/// keyframe-selection precedent) and, like every selection, it is
/// deliberately not undoable.
final class AudioSelectionController extends Notifier<SelectedAudioTrack?> {
  @override
  SelectedAudioTrack? build() {
    ref.listen(selectionProvider, (_, next) {
      if (state != null && next.isNotEmpty) state = null;
    });
    return null;
  }

  /// Selects [track] (an audio lane tap).
  ///
  /// A method rather than a setter to keep the `select`/`clear` verb pair
  /// the selection controllers established.
  // ignore: use_setters_to_change_properties -- the selection vocabulary is select and clear
  void select(SelectedAudioTrack track) => state = track;

  /// Empties the selection (an element tap, a removed track).
  void clear() => state = null;
}

/// The audio selection for the mounted editor scope.
final audioSelectionProvider = NotifierProvider<AudioSelectionController, SelectedAudioTrack?>(
  AudioSelectionController.new,
);
