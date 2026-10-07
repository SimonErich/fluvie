import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/audio/encoding/audio_mix_staging.dart';
import 'package:fluvie/src/composition/runtime/aspect_scope.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_capability_exception.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';
import 'package:fluvie/src/media/render_resolver_scope.dart';
import 'package:fluvie/src/rendering/assets/project_asset_bundle.dart';
import 'package:fluvie/src/rendering/assets/render_fonts.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/capture_mounted_snapshots.dart';
import 'package:fluvie/src/rendering/clip_audio_staging.dart';
import 'package:fluvie/src/rendering/composition_session.dart';
import 'package:fluvie/src/rendering/render_cancellation.dart';
import 'package:fluvie/src/rendering/render_host_context.dart';
import 'package:fluvie/src/rendering/render_invocation.dart';
import 'package:fluvie/src/rendering/render_options.dart';
import 'package:fluvie/src/rendering/render_video.dart';
import 'package:fluvie/src/rendering/request_video_renderer.dart';
import 'package:fluvie/src/rendering/review_text.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/video_render_request.dart';
import 'package:fluvie/src/rendering/video_renderer.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

export 'render_host_context.dart' show RenderHostContext;
export 'render_invocation.dart' show RenderInvocation;

part 'render_host_operations.dart';
part 'render_host_custom.dart';
part 'render_host_audio.dart';
part 'render_host_review.dart';
part 'render_host_mount.dart';
part 'render_host_review_fresh.dart';

/// An encoded-output renderer factory imported statically by a CLI adapter.
/// The renderer owns its codec and must reject request options it cannot honor.
typedef RenderFactory = FutureOr<VideoRenderer<File>> Function(RenderHostContext host);

/// Runs Fluvie's package-owned harness over an authored composition.
///
/// A generated adapter only supplies the builder and host callbacks. The
/// default writes capture data; a [rendererFactory] returns an already encoded
/// file. `render-result.json` is written last and tells the CLI which path ran.
/// Review calls [videoFactory] again when checking a fresh mount. Without a
/// factory, review checks fresh widget state using the supplied [video].
Future<void> runFluvieRender({
  required Video video,
  required RenderHostContext host,
  FutureOr<Video> Function()? videoFactory,
  RenderInvocation? invocation,
  RenderFactory? rendererFactory,
}) async {
  final request = invocation ?? RenderInvocation.fromEnvironment();
  if (!const {'render', 'inspect', 'frame', 'audio', 'review'}.contains(request.operation)) {
    throw ArgumentError.value(
      request.operation,
      'operation',
      'expected render, inspect, frame, review or audio',
    );
  }
  host
    ..video = video
    ..invocation = request;
  await host.runAsync(() async {
    await Directory(request.outputDir).create(recursive: true);
    final receipt = File('${request.outputDir}/render-result.json');
    if (receipt.existsSync()) receipt.deleteSync();
    host.assets = await ProjectAssetBundle.fromProject(
      request.projectDir ?? Directory.current.path,
    );
    await loadRenderFonts(bundle: host.assets);
    return null;
  });
  host.cancellation.throwIfCancelled();
  final result = <String, Object>{'schemaVersion': 1};
  final fingerprint = request.compositionFingerprint;
  final captureKey = fingerprint == null || fingerprint.isEmpty
      ? request.compositionKey
      : '${request.compositionKey}:$fingerprint';
  if (rendererFactory != null) {
    result.addAll(await _renderCustom(host, rendererFactory, captureKey));
  } else {
    final scope = resolverScope(
      null,
      assetBundle: host.assets,
      whenCancelled: host.cancellation.whenCancelled,
    );
    try {
      if (request.operation == 'inspect' ||
          request.operation == 'audio' ||
          request.operation == 'review') {
        result.addAll(await _prepareOperation(host, scope.resolver, videoFactory: videoFactory));
      } else {
        if (request.operation == 'frame' &&
            (request.frameIndex < 0 || request.frameIndex >= video.totalFrames)) {
          throw ArgumentError.value(
            request.frameIndex,
            'frameIndex',
            'must be within 0..${video.totalFrames - 1}',
          );
        }
        await renderVideo(
          video: video,
          outDir: Directory(request.outputDir),
          pumpWidget: (tree) =>
              host.pumpWidget(DefaultAssetBundle(bundle: host.assets, child: tree)),
          pumpFrame: host.pumpFrame,
          setViewSize: host.setViewSize,
          runAsync: host.runAsync,
          resolver: scope.resolver,
          cancellation: host.cancellation,
          compositionKey: captureKey,
          frameCountOverride: request.operation == 'frame' ? 1 : request.frameCount,
          frameStart: request.operation == 'frame' ? request.frameIndex : 0,
          cacheEnabled: request.cacheEnabled,
          aspect: request.aspect,
          quality: request.quality,
          export: request.export,
          posterTime: request.posterTime,
          defaultFontFamily: fluvieDefaultFontFamily,
          onProgress: (completed, total) => writeRenderProgress(
            Platform.environment['FLUVIE_PROGRESS_FILE'] ?? '${request.outputDir}/progress.txt',
            completed,
            total,
          ),
          onCacheReport: (hits, total) => stdout.writeln('fluvie cache: $hits/$total hits'),
        );
        if (request.operation == 'frame') {
          await host.runAsync(() async {
            final size = request.aspect?.sizeFor(
              video.width > video.height ? video.width : video.height,
            );
            final width = size?.width ?? video.width;
            final height = size?.height ?? video.height;
            final rgba = await File('${request.outputDir}/frames.rgba').readAsBytes();
            final ready = Completer<ui.Image>();
            ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, ready.complete);
            final image = await ready.future;
            try {
              final png = await image.toByteData(format: ui.ImageByteFormat.png);
              if (png == null) {
                throw StateError('Flutter could not encode the requested frame as PNG.');
              }
              final file = File('${request.outputDir}/frame.png');
              await file.writeAsBytes(png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes));
              result.addAll({'kind': 'frame', 'filePath': file.absolute.path});
            } finally {
              image.dispose();
            }
            return null;
          });
        } else {
          result.addAll({
            'kind': 'capture',
            'manifestPath': '${Directory(request.outputDir).absolute.path}/manifest.json',
          });
        }
      }
    } finally {
      await host.runAsync(() async {
        await scope.dispose();
        return null;
      });
    }
  }
  host.cancellation.throwIfCancelled();
  await host.runAsync(() async {
    final receipt = File('${request.outputDir}/render-result.json');
    await File('${receipt.path}.tmp').writeAsString(jsonEncode(result), flush: true);
    await File('${receipt.path}.tmp').rename(receipt.path);
    return null;
  });
}
