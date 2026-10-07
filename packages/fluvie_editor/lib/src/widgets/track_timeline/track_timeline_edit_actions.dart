part of 'track_timeline.dart';

/// Bar edits, cross-artifact drag lifecycle and external-drop intentions.
final class TrackTimelineEditActions {
  /// Configures edit without side effects or callback wrapping.
  const TrackTimelineEditActions({
    this.onBarMoved,
    this.onBarResized,
    this.onEasingTapped,
    this.onForeignDrop,
    this.onForeignLaneDrop,
    this.onDragStarted,
    this.onDragEnded,
  });

  /// Hears a bar body drag: the bar, its would-be new start frame, and the id
  /// of the lane the pointer is over.
  ///
  /// The lane is read from where the pointer *is* rather than from the
  /// distance travelled, so a drag that overshoots and comes back lands where
  /// it looks like it will, and it clamps to the first or last row past the
  /// ends. It is reported on every move, including the ones that stay on the
  /// bar's own lane, so a host never has to remember which lane it started on.
  ///
  /// The widget does not re-lane the bar. As with every other callback here it
  /// reports an intention: a host that has no lanes to move between ignores the
  /// id, and one that does re-renders with new [TrackTimeline.tracks].
  final void Function(String barId, double newStart, String targetTrackId)? onBarMoved;

  /// Hears an edge drag: the bar and its would-be new span.
  final void Function(String barId, double newStart, double newEnd)? onBarResized;

  /// A click close to the painted easing curve, after selecting its bar.
  final ValueChanged<String>? onEasingTapped;

  /// A payload from outside the timeline dropped on the lanes: the data,
  /// the bar under the pointer (or null between bars), and the frame. The
  /// timeline stays domain-free — the host decides what a payload means.
  final void Function(Object data, String? barId, double frame)? onForeignDrop;

  /// A foreign payload dropped onto a row, including empty declared lanes.
  /// When present this receives the drop instead of [TrackTimelineEditActions.onForeignDrop].
  final void Function(Object data, String trackId, String? barId, double frame)? onForeignLaneDrop;

  /// Hears the first motion of a bar or diamond drag — the host's cue to
  /// open one coalescing undo group for the run of moves that follows.
  final ValueChanged<String>? onDragStarted;

  /// Hears the end of a bar or diamond drag (release or cancel).
  final ValueChanged<String>? onDragEnded;
}
