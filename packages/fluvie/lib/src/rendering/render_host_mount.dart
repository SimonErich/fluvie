part of 'render_host.dart';

/// One mounted operation, including resources that must never survive a remount.
final class _MountedHostComposition {
  _MountedHostComposition(this.host, this.video, MediaResolver resolver)
    : session = CompositionSession(
        composition: video,
        resolver: resolver,
        loadCubeText: host.assets.loadString,
        cancellation: host.cancellation,
      );

  final RenderHostContext host;
  final Video video;
  final CompositionSession session;
  final RenderController controller = RenderController();
  final GlobalKey boundary = GlobalKey();
  SnapshotCaptureScope? _snapshots;
  SnapshotCaptureScope? _mountedSnapshots;
  bool _closed = false;
  Future<void>? _mounting;

  bool get _review => host.invocation.operation == 'review';
  int get width => _size?.width ?? video.width;
  int get height => _size?.height ?? video.height;
  VideoSize? get _size => host.invocation.aspect?.sizeFor(
    video.width > video.height ? video.width : video.height,
  );

  Widget _tree() {
    Widget composition = Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: fluvieDefaultFontFamily),
        child: video,
      ),
    );
    final aspect = host.invocation.aspect;
    if (aspect != null) composition = AspectScope(aspect: aspect, child: composition);
    final shell = buildCaptureShell(
      composition: session.mountTree(composition),
      boundaryKey: boundary,
      controller: controller,
      snapshotScope: _snapshots,
    );
    _mountedSnapshots = shell.mountedSnapshotScope;
    return shell.tree;
  }

  Future<void> _mount(Widget tree) async {
    final finished = Completer<void>();
    // WidgetTester's pump can flush cancellation microtasks before returning its
    // Future, so publish the teardown barrier before entering the host callback.
    _mounting = finished.future;
    try {
      await host.pumpWidget(DefaultAssetBundle(bundle: host.assets, child: tree));
      host.cancellation.throwIfCancelled();
    } finally {
      finished.complete();
      _mounting = null;
    }
  }

  Future<T?> _runAsync<T>(Future<T> Function() callback) => _runHostAsync(host, callback);

  Future<void> prepare() async {
    host.cancellation.throwIfCancelled();
    host.setViewSize(width, height);
    await session.prepare(
      mount: _mount,
      pump: host.pumpFrame,
      runAsync: _runAsync,
      buildTree: _tree,
      beforeReady: _review
          ? () async {
              await _runAsync(() async {
                _snapshots = await captureMountedSnapshots(
                  session: session,
                  pump: () => _mount(_tree()),
                );
                return null;
              });
              host.setViewSize(width, height);
            }
          : null,
      activate: _review,
      prepareFirstFrame: _review,
      warmEffects: _review,
      prepareSnapshots: _review,
    );
  }

  Future<RawFrame> frameAt(int frame) async {
    host.cancellation.throwIfCancelled();
    controller.seek(frame);
    await _runAsync(() async {
      await session.prepareFrame(frame);
      return null;
    });
    _mountedSnapshots?.resetCursor();
    await host.pumpFrame();
    session.validateFrameResources();
    final result = await _runAsync(
      () => const RepaintBoundaryCaptureService().capture(
        boundaryKey: boundary,
        frameIndex: frame,
        width: width,
        height: height,
      ),
    );
    if (result == null) throw StateError('Review capture returned no frame.');
    session.finishFrame();
    host.cancellation.throwIfCancelled();
    return result;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      // A cancellation race can finish before Flutter's current pump completes.
      await _mounting;
      // Dispose StatefulWidgets before releasing the images they may still paint.
      await host.pumpWidget(const SizedBox.shrink());
    } finally {
      for (final image in _snapshots?.images.values ?? const <ui.Image>[]) {
        image.dispose();
      }
      session.dispose();
      controller.dispose();
    }
  }
}

Future<T?> _runHostAsync<T>(RenderHostContext host, Future<T> Function() callback) async {
  Object? failure;
  StackTrace? trace;
  final result = await host.runAsync(() async {
    try {
      return await callback();
    } on Object catch (error, stack) {
      // WidgetTester.runAsync reports uncaught errors and returns null. Preserve
      // the typed cause inside its callback, then rethrow in the caller's zone.
      failure = error;
      trace = stack;
      return null;
    }
  });
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  return result;
}
