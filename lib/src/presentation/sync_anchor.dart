import 'package:flutter/widgets.dart';

import '../domain/sync_anchor_info.dart';
import 'sync_anchor_registry.dart';

/// A widget that marks a sync point in the composition timeline.
///
/// [SyncAnchor] registers timing information that other widgets can reference
/// via [syncStartWith] and [syncEndWith] parameters. This enables loose coupling
/// between animations and audio tracks that need to synchronize.
///
/// ## Example
///
/// ```dart
/// // Mark a sync point for the intro text
/// SyncAnchor(
///   anchorId: 'intro_text',
///   startFrame: 30,
///   endFrame: 120,
///   child: AnimatedProp.fadeIn(
///     duration: 30,
///     child: Text('Welcome'),
///   ),
/// )
///
/// // Elsewhere, sync audio to start with the intro
/// AudioTrack.syncStart(
///   source: AudioSource.asset('intro_music.mp3'),
///   syncWithAnchor: 'intro_text',
///   startOffset: -10,  // Start 10 frames before the text
///   durationInFrames: 150,
/// )
/// ```
///
/// ## Offset Parameters
///
/// The [startOffset] and [endOffset] parameters allow fine-tuning:
/// - Positive offset: shifts the sync point later in time
/// - Negative offset: shifts the sync point earlier in time
///
/// These offsets are applied when other widgets resolve their sync references.
class SyncAnchor extends StatefulWidget {
  /// Unique identifier for this sync anchor.
  ///
  /// Other widgets reference this ID via [syncStartWith] or [syncEndWith].
  final String anchorId;

  /// The frame at which this anchor becomes active.
  final int startFrame;

  /// The frame at which this anchor ends.
  ///
  /// If null, the anchor has no defined end point.
  final int? endFrame;

  /// Offset added to the start frame when resolving sync references.
  ///
  /// Use this to fine-tune timing relationships without changing the
  /// actual animation timing.
  final int startOffset;

  /// Offset added to the end frame when resolving sync references.
  ///
  /// Use this to fine-tune timing relationships without changing the
  /// actual animation timing.
  final int endOffset;

  /// The child widget.
  final Widget child;

  /// Creates a sync anchor widget.
  const SyncAnchor({
    super.key,
    required this.anchorId,
    required this.startFrame,
    this.endFrame,
    this.startOffset = 0,
    this.endOffset = 0,
    required this.child,
  });

  /// Creates a sync anchor that spans the entire composition.
  ///
  /// Use this for global sync points like background music.
  factory SyncAnchor.global({
    Key? key,
    required String anchorId,
    int startOffset = 0,
    int endOffset = 0,
    required Widget child,
  }) {
    return SyncAnchor(
      key: key,
      anchorId: anchorId,
      startFrame: 0,
      endFrame: null, // Will be resolved to composition end
      startOffset: startOffset,
      endOffset: endOffset,
      child: child,
    );
  }

  @override
  State<SyncAnchor> createState() => _SyncAnchorState();
}

class _SyncAnchorState extends State<SyncAnchor> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerAnchor();
  }

  @override
  void didUpdateWidget(SyncAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchorId != widget.anchorId ||
        oldWidget.startFrame != widget.startFrame ||
        oldWidget.endFrame != widget.endFrame ||
        oldWidget.startOffset != widget.startOffset ||
        oldWidget.endOffset != widget.endOffset) {
      // Unregister old anchor if ID changed
      if (oldWidget.anchorId != widget.anchorId) {
        _unregisterAnchor(oldWidget.anchorId);
      }
      _registerAnchor();
    }
  }

  @override
  void dispose() {
    _unregisterAnchor(widget.anchorId);
    super.dispose();
  }

  void _registerAnchor() {
    final registry = SyncAnchorRegistry.maybeOf(context);
    if (registry != null) {
      registry.registerAnchor(
        SyncAnchorInfo(
          anchorId: widget.anchorId,
          startFrame: widget.startFrame + widget.startOffset,
          endFrame: widget.endFrame != null
              ? widget.endFrame! + widget.endOffset
              : null,
        ),
      );
    }
  }

  void _unregisterAnchor(String anchorId) {
    final registry = SyncAnchorRegistry.maybeOf(context);
    registry?.unregisterAnchor(anchorId);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Extension methods for resolving sync references.
extension SyncAnchorResolution on BuildContext {
  /// Resolves a start frame from a sync anchor ID.
  ///
  /// Returns [fallback] if the anchor doesn't exist.
  int resolveSyncStart(String? anchorId, {int offset = 0, int fallback = 0}) {
    if (anchorId == null) return fallback;
    final registry = SyncAnchorRegistry.of(this);
    return registry?.data.resolveStartFrame(anchorId, offset: offset) ??
        fallback;
  }

  /// Resolves an end frame from a sync anchor ID.
  ///
  /// Returns [fallback] if the anchor doesn't exist or has no end frame.
  int? resolveSyncEnd(String? anchorId, {int offset = 0, int? fallback}) {
    if (anchorId == null) return fallback;
    final registry = SyncAnchorRegistry.of(this);
    return registry?.data.resolveEndFrame(anchorId, offset: offset) ?? fallback;
  }
}
