import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/runtime/aspect_scope.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/rendering/capture_mounted_snapshots.dart';
import 'package:fluvie/src/rendering/composition_session.dart';
import 'package:fluvie/src/rendering/prepared_composition.dart';
import 'package:fluvie/src/rendering/render_host_callbacks.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/video_render_request.dart';

/// Mounted capture lifecycle shared by directory and sandbox render adapters.
///
/// Owns the session, controller and captured snapshot images. Media resolver
/// ownership remains with the calling adapter's resolver scope.
final class CompositionCaptureHost {
  /// Takes ownership of [session] and its Flutter capture resources.
  CompositionCaptureHost({required this.session, required VideoRenderRequest request})
    : _request = request,
      _authored = request.composition;

  /// Prepared composition and frame-resource lifecycle.
  final CompositionSession session;

  /// Boundary from which the adapter captures pixels.
  final GlobalKey boundaryKey = GlobalKey();

  final Widget _authored;
  final RenderController _controller = RenderController();
  VideoRenderRequest _request;
  SnapshotCaptureScope? _snapshotScope;
  SnapshotCaptureScope? _mountedSnapshots;

  /// Request with mounted authored export and poster settings applied.
  VideoRenderRequest get request => _request;

  Widget _tree() {
    final shell = buildCaptureShell(
      composition: session.mountTree(
        _request.aspect == null
            ? _authored
            : AspectScope(aspect: _request.aspect!, child: _authored),
      ),
      boundaryKey: boundaryKey,
      controller: _controller,
      snapshotScope: _snapshotScope,
    );
    _mountedSnapshots = shell.mountedSnapshotScope;
    return shell.tree;
  }

  /// Resolves mounted resources and freezes snapshots before output capture.
  Future<void> prepare({
    required ShellMount mount,
    required ShellFramePump pump,
    ShellRunAsync runAsync = runAsyncDirectly,
    FutureOr<void> Function(PreparedComposition prepared, VideoRenderRequest request)? onPrepared,
  }) => session.prepare(
    mount: mount,
    pump: pump,
    buildTree: _tree,
    runAsync: runAsync,
    beforeReady: () async {
      _request = session.prepared.resolveRequest(_request);
      await onPrepared?.call(session.prepared, _request);
      await runAsync(() async {
        _snapshotScope = await captureMountedSnapshots(
          session: session,
          pump: () => mount(_tree()),
        );
        return null;
      });
    },
  );

  /// Prepares, seeks and validates one output frame using the host's pump.
  Future<void> pumpFrame(int frame, ShellFramePump pump) async {
    await session.prepareFrame(frame);
    _controller.seek(frame);
    _mountedSnapshots?.resetCursor();
    await pump();
    session
      ..validateFrameResources()
      ..finishFrame();
  }

  /// Releases the captured images, composition session and frame controller.
  void dispose() {
    if (_snapshotScope case final snapshots?) {
      for (final image in snapshots.images.values) {
        image.dispose();
      }
    }
    session.dispose();
    _controller.dispose();
  }
}
