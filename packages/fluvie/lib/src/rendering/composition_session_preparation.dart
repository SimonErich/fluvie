part of 'composition_session.dart';

extension _MountedPreparation on CompositionSession {
  Future<void> _prepare({
    required Future<void> Function(Widget tree) mount,
    required Future<void> Function() pump,
    required Widget Function() buildTree,
    required Future<T?> Function<T>(Future<T> Function() callback) runAsync,
    Future<void> Function()? beforeReady,
    bool prepareFirstFrame = true,
    bool activate = true,
    bool warmEffects = true,
    bool prepareSnapshots = true,
  }) async {
    var stable = false;
    for (var pass = 0; pass < CompositionSession.maximumDiscoveryPasses; pass++) {
      cancellation?.throwIfCancelled();
      await _run(() => mount(buildTree()));
      final changed = discover();
      await runAsync(() async {
        await prepareResources(warmEffects: warmEffects, prepareSnapshots: prepareSnapshots);
        return null;
      });
      cancellation?.throwIfCancelled();
      if (!changed && pass > 0) {
        stable = true;
        break;
      }
    }
    if (!stable) {
      throw FluvieRenderException(
        'Composition resources keep changing during preparation. '
        'Declare frame-dependent alternatives with Video.resources or Scene.resources.',
      );
    }
    // Resolve the real mounted registrations while leaves are still offscreen.
    // Inspection validates the same plan without capturing or decoding frames.
    cancellation?.throwIfCancelled();
    _validateMountedTransitions();
    _resolvingTiming = true;
    await mount(buildTree());
    await pump();
    if (_timingError case final error?) throw error;
    _validateMountedTransitions();
    _resolvingTiming = false;
    await mount(buildTree());
    cancellation?.throwIfCancelled();
    _resourcesPrepared = true;
    await beforeReady?.call();
    cancellation?.throwIfCancelled();
    if (!activate) return;
    if (prepareFirstFrame) {
      await runAsync(() async {
        await prepareFrame(0);
        return null;
      });
    }
    cancellation?.throwIfCancelled();
    preparing = false;
    await mount(buildTree());
    // Deferred timing registration resolves on the first ready frame; its
    // injected schedules reach every element on the next pump.
    await pump();
  }
}
