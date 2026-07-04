import 'dart:io';

import 'package:flutter/widgets.dart' show Directionality, TextDirection, Widget, debugPrint;
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart' show MediaResolver;
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/render_phase.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/media/render_resolver_scope.dart';
import 'package:fluvie/src/rendering/audio_mix_resolution.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/platform/process_ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/render_aspect.dart' as capture;
import 'package:fluvie/src/rendering/render_cleanup.dart';
import 'package:fluvie/src/rendering/render_duration.dart';
import 'package:fluvie/src/rendering/render_progress.dart';
import 'package:fluvie/src/rendering/render_service.dart';
import 'package:fluvie/src/rendering/render_stage.dart';
import 'package:fluvie/src/rendering/video_renderer.dart';

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
final class DesktopVideoRenderer implements VideoRenderer<File> {
  /// Creates a renderer over its seams; the defaults target a real desktop.
  DesktopVideoRenderer({
    required this.pumpWidget,
    required this.pumpFrame,
    FfmpegRunner? runner,
    RenderService? service,
    Future<Directory> Function()? sandboxFactory,
    this.mediaResolver,
    this.networkAllowlist,
  }) : _runner = runner ?? ProcessFfmpegRunner(),
       _service = service ?? RenderService(capture: const RepaintBoundaryCaptureService()),
       _sandboxFactory = sandboxFactory ?? _defaultSandboxFactory;

  /// Sink for renderer warnings (e.g. a `Video` declares audio but `audio:
  /// false` drops it). Defaults to [debugPrint]; replace it to route warnings.
  static void Function(String message) onWarning = _defaultWarn;

  // coverage:ignore-line the default sink runs only when onWarning is not overridden which tests always do
  static void _defaultWarn(String message) => debugPrint('fluvie: $message');

  /// Mounts the capture shell into the host's element tree.
  final capture.ShellMount pumpWidget;

  /// Pumps the host one frame after each seek.
  final capture.ShellFramePump pumpFrame;

  final FfmpegRunner _runner;
  final RenderService _service;
  final Future<Directory> Function() _sandboxFactory;

  /// The injected media resolver, or null to build (and dispose) one per
  /// [render] from `mediaResolverProvider`. Pass one to inject a fake.
  final MediaResolver? mediaResolver;

  /// Restricts which hosts network media may be fetched from. Applied to the
  /// per-render resolver when none is injected; ignored when [mediaResolver]
  /// is provided (configure the allowlist on it instead).
  final NetworkAllowlist? networkAllowlist;

  /// Renders [composition] for [aspect] over [duration] to an MP4 file in a
  /// fresh sandbox directory, returning that file.
  ///
  /// With [audio] left `true`, a `Video`'s declared `Audio` tracks are staged
  /// into the FFmpeg mix; pass `false` for a silent render (warned once
  /// through [onWarning] unless [warnOnDroppedAudio] is `false`).
  @override
  Future<File> render({
    required Widget composition,
    required Aspect aspect,
    required Duration duration,
    int fps = VideoDefaults.fps,
    int longEdge = VideoDefaults.longEdge,
    bool audio = true,
    bool warnOnDroppedAudio = true,
    String compositionKey = 'render',
    RenderProgressCallback? onProgress,
  }) async {
    final frameCount = frameCountFor(duration, fps);
    final sandbox = await _sandboxFactory();
    final scope = resolverScope(mediaResolver, networkAllowlist: networkAllowlist);
    try {
      if (!audio) _warnIfDroppingAudio(composition, warnOnDroppedAudio, fps, frameCount);
      onProgress?.call(RenderProgress(RenderPhase.capturing, compositionKey: compositionKey));
      final result = await runStage(
        RenderPhase.capturing,
        () => capture.render(
          // The host mounts this with no app ancestors, so the tree needs an
          // ambient Directionality for Text/RichText to lay out. Audio is
          // collected from the raw Video by the capture entry itself, so the
          // wrap is mount-only.
          composition: Directionality(textDirection: TextDirection.ltr, child: composition),
          aspect: aspect,
          frameCount: frameCount,
          outDir: sandbox,
          service: _service,
          pumpWidget: pumpWidget,
          pumpFrame: pumpFrame,
          longEdge: longEdge,
          fps: fps,
          compositionKey: compositionKey,
          stageAudio: audio ? null : _silentAudio,
          resolver: scope.resolver,
        ),
      );
      final manifest = result.manifest;
      onProgress?.call(RenderProgress(RenderPhase.encoding, compositionKey: compositionKey));
      await runStage(RenderPhase.encoding, () async {
        await _runner.encode(args: manifest.ffmpegArgs, sandbox: sandbox);
        final posterArgs = manifest.posterArgs;
        if (posterArgs != null) {
          await _runner.encode(args: posterArgs, sandbox: sandbox);
        }
      });
      onProgress?.call(RenderProgress(RenderPhase.complete, compositionKey: compositionKey));
      return File('${sandbox.path}/${manifest.outputFileName}');
    } finally {
      await runGuarded([
        scope.dispose,
      ], (error, _) => onWarning('Cleanup after render failed: $error'));
    }
  }

  /// Warns once when [composition] declares audio that `audio: false` drops.
  void _warnIfDroppingAudio(Widget composition, bool warn, int fps, int frameCount) {
    if (!warn || composition is! Video) return;
    final mix = resolveAudioMix(video: composition, fps: fps, totalFrames: frameCount);
    if (mix.isEmpty) return;
    onWarning(
      'This Video declares ${mix.tracks.length} audio track(s), but audio is '
      'off, so the MP4 will be silent. Leave audio: true to encode it, or pass '
      'warnOnDroppedAudio: false to silence this warning.',
    );
  }

  static Future<Directory> _defaultSandboxFactory() =>
      Directory.systemTemp.createTemp('fluvie_desktop_render_');
}

Future<AudioMixLanes> _silentAudio({
  required MediaResolver resolver,
  required Directory sandbox,
}) async => (nodes: const <Never>[], amix: null);
