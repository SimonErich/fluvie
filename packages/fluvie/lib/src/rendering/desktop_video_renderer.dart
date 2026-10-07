import 'dart:io';

import 'package:flutter/widgets.dart' show Directionality, TextDirection, Widget, debugPrint;
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/contracts/clip_timeline_resolver.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart' show MediaResolver;
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/core/render_phase.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/media/render_resolver_scope.dart';
import 'package:fluvie/src/rendering/audio_opt_in_gate.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/platform/process_ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/render_aspect.dart' as capture;
import 'package:fluvie/src/rendering/render_cancellation.dart';
import 'package:fluvie/src/rendering/render_cleanup.dart';
import 'package:fluvie/src/rendering/render_duration.dart';
import 'package:fluvie/src/rendering/render_progress.dart';
import 'package:fluvie/src/rendering/render_service.dart';
import 'package:fluvie/src/rendering/render_stage.dart';
import 'package:fluvie/src/rendering/request_video_renderer.dart';
import 'package:fluvie/src/rendering/video_render_request.dart';
import 'package:fluvie/src/rendering/video_renderer.dart';
import 'package:fluvie_media/fluvie_media.dart' show RenderCapabilities;

part 'desktop_video_renderer_capture.dart';

/// Renders a Fluvie composition to an MP4 file with a local FFmpeg.
///
/// This is the desktop arm of the [VideoRenderer] family: it runs Fluvie's
/// deterministic capture loop through the host's pump seams, then hands the
/// captured manifest's argument array to an [FfmpegRunner]. It is the same
/// path the CLI drives — this class is the symmetric in-process entry point
/// next to `OnDeviceVideoRenderer` (mobile) and `WebVideoRenderer` (browser).
///
/// Audio defaults to **on**: the local FFmpeg carries the full feature set,
/// so a `Video`'s declared `Audio` tracks are mixed in unless you pass
/// `audio: false` (which warns once, unless silenced). Every dependency is
/// injected so the orchestration is unit-testable; the host owns pumping
/// through [pumpWidget] and [pumpFrame] (a widget test passes the tester's,
/// the CLI passes its binding's).
final class DesktopVideoRenderer implements VideoRenderer<File>, RequestVideoRenderer<File> {
  /// Creates a renderer over its seams; the defaults target a real desktop.
  DesktopVideoRenderer({
    required this.pumpWidget,
    required this.pumpFrame,
    FfmpegRunner? runner,
    RenderService? service,
    Future<Directory> Function()? sandboxFactory,
    void Function(String message)? onWarning,
    this.mediaResolver,
    this.networkAllowlist,
    this.cancellation,
    // ignore: prefer_initializing_formals — the public runner parameter keeps its established name.
  }) : _runner = runner,
       _service = service ?? RenderService(capture: const RepaintBoundaryCaptureService()),
       _sandboxFactory = sandboxFactory ?? _defaultSandboxFactory,
       _onWarning = onWarning ?? _defaultWarn;

  /// Sink for renderer warnings (e.g. a `Video` declares audio but `audio:
  /// false` drops it). Defaults to [debugPrint]; inject one to route warnings.
  final void Function(String message) _onWarning;

  // coverage:ignore-line the default sink runs only when no onWarning is injected which tests always do
  static void _defaultWarn(String message) => debugPrint('fluvie: $message');

  /// Mounts the capture shell into the host's element tree.
  final capture.ShellMount pumpWidget;

  /// Pumps the host one frame after each seek.
  final capture.ShellFramePump pumpFrame;

  final FfmpegRunner? _runner;
  final RenderService _service;
  final Future<Directory> Function() _sandboxFactory;

  /// The injected media resolver, or null to build (and dispose) one per
  /// [render] from `mediaResolverProvider`. Pass one to inject a fake.
  final MediaResolver? mediaResolver;

  /// Restricts which hosts network media may be fetched from. Applied to the
  /// per-render resolver when none is injected; ignored when [mediaResolver]
  /// is provided (configure the allowlist on it instead).
  final NetworkAllowlist? networkAllowlist;

  /// Optional cancellation shared with the owning export job.
  final RenderCancellation? cancellation;

  /// Renders [composition] for [aspect] over [duration] to an MP4 file in a
  /// fresh sandbox directory, returning that file.
  ///
  /// With [audio] left `true`, a `Video`'s declared `Audio` tracks are staged
  /// into the FFmpeg mix; pass `false` for a silent render (warned once
  /// through the injected warning sink unless [warnOnDroppedAudio] is `false`).
  @override
  Future<File> render({
    required Widget composition,
    required Aspect aspect,
    required Duration duration,
    int fps = VideoDefaults.fps,
    int longEdge = VideoDefaults.longEdge,
    Quality? quality,
    bool audio = true,
    bool warnOnDroppedAudio = true,
    String compositionKey = 'render',
    RenderProgressCallback? onProgress,
  }) async {
    final size = aspect.sizeFor(longEdge);
    return renderRequest(
      VideoRenderRequest(
        composition: composition,
        width: size.width,
        height: size.height,
        fps: fps,
        frameCount: frameCountFor(duration, fps),
        aspect: aspect,
        quality: quality,
        audio: audio,
        warnOnDroppedAudio: warnOnDroppedAudio,
        compositionKey: compositionKey,
        onProgress: onProgress,
        cancellation: cancellation,
      ),
    );
  }

  @override
  RenderCapabilities get capabilities => RenderCapabilities.desktop;

  @override
  Future<File> renderRequest(VideoRenderRequest request) => _renderRequest(request);

  static Future<Directory> _defaultSandboxFactory() =>
      Directory.systemTemp.createTemp('fluvie_desktop_render_');
}

Future<AudioMixLanes> _silentAudio({
  required MediaResolver resolver,
  required Directory sandbox,
}) async => (nodes: const <Never>[], amix: null);
