import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The in and out points marked on the timeline, in composition frames.
///
/// Aim rather than an edit: nothing here changes the document, which is why
/// it lives beside the history rather than inside it. A verb that needs a
/// range reads [span] and gets null unless the pair really is one.
@immutable
final class TimelineMarks {
  /// Marks [markIn] and [markOut]; either may be absent.
  const TimelineMarks({this.markIn, this.markOut});

  /// The in point, or null.
  final int? markIn;

  /// The out point, or null.
  final int? markOut;

  /// The marked range, or null when the pair is not one.
  ///
  /// Half a mark is not a range, and neither is an out at or before the in.
  /// Which of the two gives way when an author marks an inverted pair is the
  /// scope's decision, not this state's: it stores what it is told.
  ({int start, int end})? get span {
    final start = markIn;
    final end = markOut;
    if (start == null || end == null || end <= start) return null;
    return (start: start, end: end);
  }

  @override
  bool operator ==(Object other) =>
      other is TimelineMarks && other.markIn == markIn && other.markOut == markOut;

  @override
  int get hashCode => Object.hash(markIn, markOut);

  @override
  String toString() => 'TimelineMarks(in: $markIn, out: $markOut)';
}

/// Owns the marks for the mounted editor.
final class TimelineMarksController extends Notifier<TimelineMarks> {
  @override
  TimelineMarks build() => const TimelineMarks();

  /// Replaces both marks. A call naming neither clears them, because the
  /// commands say "clear" by naming nothing.
  void set({int? markIn, int? markOut}) => state = TimelineMarks(markIn: markIn, markOut: markOut);
}

/// The in and out points for the mounted editor.
final timelineMarksProvider = NotifierProvider<TimelineMarksController, TimelineMarks>(
  TimelineMarksController.new,
);
