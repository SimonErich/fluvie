import 'dart:async';

import 'package:flutter/widgets.dart';

/// Provides render mode context to descendant widgets.
///
/// When [isRendering] is true, widgets like [EmbeddedVideo] should ensure
/// all async operations complete before the frame is captured.
///
/// Example:
/// ```dart
/// RenderModeProvider(
///   isRendering: true,
///   frameReadyNotifier: notifier,
///   child: composition,
/// )
/// ```
class RenderModeProvider extends InheritedWidget {
  /// Whether we are currently in render mode (capturing frames for final video).
  final bool isRendering;

  /// Notifier that tracks pending frame operations.
  ///
  /// Widgets should register pending async operations with this notifier
  /// so the render loop can wait for them to complete before capturing.
  final FrameReadyNotifier? frameReadyNotifier;

  /// Creates a render mode provider.
  const RenderModeProvider({
    super.key,
    required this.isRendering,
    this.frameReadyNotifier,
    required super.child,
  });

  /// Gets the render mode context from the widget tree.
  ///
  /// Returns null if no [RenderModeProvider] is found in the tree.
  static RenderModeProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RenderModeProvider>();
  }

  /// Whether we are currently in render mode.
  ///
  /// Returns false if no [RenderModeProvider] is found in the tree.
  static bool isRenderMode(BuildContext context) {
    return of(context)?.isRendering ?? false;
  }

  @override
  bool updateShouldNotify(RenderModeProvider oldWidget) {
    return isRendering != oldWidget.isRendering ||
        frameReadyNotifier != oldWidget.frameReadyNotifier;
  }
}

/// Tracks pending async frame operations during rendering.
///
/// When capturing frames for the final video, the render loop should:
/// 1. Update the frame
/// 2. Wait for rasterization
/// 3. Call [waitForAllFrames] to ensure all async operations complete
/// 4. Capture the frame
///
/// Widgets with async operations (like [EmbeddedVideo]) should:
/// 1. Call [registerPendingFrame] before starting async work
/// 2. Call [markFrameReady] when the work completes
class FrameReadyNotifier extends ChangeNotifier {
  final Set<Completer<void>> _pendingFrames = {};

  /// Number of pending frame operations.
  int get pendingCount => _pendingFrames.length;

  /// Whether there are any pending frame operations.
  bool get hasPending => _pendingFrames.isNotEmpty;

  /// Registers a pending frame operation.
  ///
  /// Returns a [Completer] that should be completed when the operation finishes.
  Completer<void> registerPendingFrame() {
    final completer = Completer<void>();
    _pendingFrames.add(completer);
    notifyListeners();
    return completer;
  }

  /// Marks a frame operation as ready (complete).
  void markFrameReady(Completer<void> completer) {
    if (!completer.isCompleted) {
      completer.complete();
    }
    _pendingFrames.remove(completer);
    notifyListeners();
  }

  /// Marks a frame operation as failed with an error.
  void markFrameFailed(Completer<void> completer, Object error) {
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
    _pendingFrames.remove(completer);
    notifyListeners();
  }

  /// Waits for all pending frame operations to complete.
  ///
  /// Returns immediately if there are no pending operations.
  Future<void> waitForAllFrames() async {
    if (_pendingFrames.isEmpty) {
      return;
    }

    // Wait for all pending frames, ignoring errors
    await Future.wait(
      _pendingFrames.map((c) => c.future.catchError((_) {})),
      eagerError: false,
    );
  }

  /// Waits for all pending frame operations with a timeout.
  ///
  /// Returns true if all frames completed within the timeout.
  /// Returns false if the timeout was reached.
  Future<bool> waitForAllFramesWithTimeout(Duration timeout) async {
    if (_pendingFrames.isEmpty) {
      return true;
    }

    try {
      await waitForAllFrames().timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  /// Clears all pending frame operations.
  ///
  /// Use with caution - only call this when aborting a render.
  void clearPending() {
    for (final completer in _pendingFrames) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Render aborted - pending frames cleared'),
        );
      }
    }
    _pendingFrames.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    clearPending();
    super.dispose();
  }
}
