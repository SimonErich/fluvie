import 'dart:io';

import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/rendering/assets/project_asset_bundle.dart';
import 'package:fluvie/src/rendering/render_cancellation.dart';
import 'package:fluvie/src/rendering/render_host_callbacks.dart';
import 'package:fluvie/src/rendering/render_invocation.dart';
import 'package:fluvie/src/rendering/render_options.dart';
import 'package:fluvie/src/rendering/render_progress.dart';
import 'package:fluvie/src/rendering/video_render_request.dart';

/// The existing Flutter host pump seams, available to custom renderer factories.
///
/// A tester supplies its callbacks; a real Flutter host supplies its own. This
/// context does not create platform channels or turn tester into a native host.
final class RenderHostContext {
  /// Creates a host without depending on a test framework.
  RenderHostContext({
    required this.pumpWidget,
    required this.pumpFrame,
    required this.setViewSize,
    this.runAsync = runAsyncDirectly,
    RenderCancellation? cancellation,
  }) : cancellation = cancellation ?? RenderCancellation();

  /// Mounts a composition shell.
  final ShellMount pumpWidget;

  /// Flushes one sought frame.
  final ShellFramePump pumpFrame;

  /// Applies the final canvas dimensions.
  final SetViewSize setViewSize;

  /// Runs real IO outside a host's fake event loop.
  final ShellRunAsync runAsync;

  /// Cooperative cancellation shared with a custom renderer.
  final RenderCancellation cancellation;

  /// The invocation bound by the CLI before a factory is called.
  late final RenderInvocation invocation;

  /// The authored composition bound before a factory is called.
  late final Video video;

  /// Complete render settings for request-aware custom adapters.
  late final VideoRenderRequest renderRequest;

  /// The dropped-assets overlay used by the default capture path.
  late final ProjectAssetBundle assets;

  /// Reports progress through the same side channel the default capture uses.
  void onProgress(RenderProgress progress) {
    final completed = progress.completedFrames;
    final total = progress.totalFrames;
    if (completed != null && total != null) {
      writeRenderProgress(
        Platform.environment['FLUVIE_PROGRESS_FILE'] ?? '${invocation.outputDir}/progress.txt',
        completed,
        total,
      );
    }
  }
}
