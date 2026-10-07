// fluvie:large-file-ok: one lifecycle owner for preparation, cancellation and bounded preview decode

import 'dart:async' show Completer, unawaited;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable, kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/runtime/color_lookup_scope.dart';
import 'package:fluvie/src/animation/runtime/warm_shader_scope.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/media/render_resolver_scope.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/media/runtime/preview_clip_scope.dart';
import 'package:fluvie/src/media/web_clip_decoder.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';
import 'package:fluvie/src/rendering/composition_session.dart';
import 'package:fluvie/src/rendering/no_generative_resolver.dart';
import 'package:fluvie/src/rendering/pre_bake_color_lookups.dart';
import 'package:fluvie/src/rendering/pre_load_shaders.dart';
import 'package:fluvie/src/rendering/pre_resolve_clips.dart';
import 'package:fluvie/src/rendering/preview_clip_frames.dart';
import 'package:fluvie/src/rendering/runtime/preparation_scope.dart';

/// Gives a live preview the media half of the capture shell: it runs the same
/// pre-resolve pass a render runs, then mounts the same [ImageResolverScope]
/// above [composition] — so `Clip`, `Background.video`, and `Image` paint
/// through the *capture* painters rather than a second, divergent decode path.
///
/// Preview already shares the clock (`RenderControllerScope` → `FrameProvider`)
/// and scene timing with capture, so the resolver is the only missing input: a
/// `Clip` with no resolver above it has nothing to paint and falls back to its
/// placeholder. Mount this inside a `LivePlayer` (which owns the ticker and the
/// render mode) to reproduce capture's depth order:
///
/// ```dart
/// LivePlayer(
///   controller: playback,
///   child: PreviewMediaScope(composition: video),
/// )
/// ```
///
/// Warm-up is asynchronous. With [frames], only requested source frames are
/// decoded and a bounded recent-frame cache serves scrubbing; without a clock,
/// the scope preserves the eager pre-pass used by existing preview hosts.
/// Failures reach [onError] (or Flutter's debug error reporter) while the media
/// element shows its fallback.
///
/// [maxClipEdge] bounds the decoded raster, without changing timing, trim or
/// source layout. A full-HD RGBA frame costs about 8.3 MB; the default proxy
/// substantially reduces the bounded scrub cache. Pass `null` for full source
/// resolution. Export uses its own resolver and ignores this preview setting.
final class PreviewMediaScope extends StatefulWidget {
  /// Pre-resolves [composition]'s media, then mounts it under a resolver.
  const PreviewMediaScope({
    required this.composition,
    this.child,
    this.warmEffects = true,
    this.frames,
    this.resolver,
    this.clipDecoder,
    this.networkAllowlist,
    this.maxClipEdge = 720,
    this.assetBundle,
    this.generative,
    this.snapshotService,
    this.beatDetector,
    this.analyzer,
    this.onError,
    this.onReady,
    super.key,
  }) : assert(
         maxClipEdge == null || maxClipEdge > 0,
         'maxClipEdge must be a positive pixel length; pass null for no bound',
       );

  /// The composition to pre-resolve and display — the `Video` (or a widget
  /// wrapping one). It is this scope's child as well as its collect target.
  final Widget composition;

  /// The mounted interactive tree. When omitted, mounts [composition].
  /// Collection always walks [composition], even when the visible tree wraps
  /// it in editor-only widgets that are not part of the composition grammar.
  final Widget? child;

  /// Whether this scope owns shader and colour-lookup warm-up. An editor with
  /// a dedicated effects host disables this to keep one resource owner.
  final bool warmEffects;

  /// An editor clock enables bounded, on-demand frame decoding. Without a
  /// clock this scope preserves the eager pre-pass used by still previews.
  final ValueListenable<int>? frames;

  /// Receives a decode failure so an authoring host can show it in release.
  /// When supplied, replaces the default debug error report.
  final ValueChanged<Object>? onError;

  /// Receives the ready resolver for thumbnails and other preview consumers.
  /// The scope retains ownership; callers must not dispose it or retain its
  /// decoded images beyond this scope's lifetime.
  final ValueChanged<MediaResolver>? onReady;

  /// A resolver to use as-is instead of building one from the platform provider
  /// (a fake in tests). The caller keeps ownership: it is never disposed here.
  ///
  /// Its type lives on the pipeline surface (`package:fluvie/rendering.dart`);
  /// an authoring preview leaves this null and gets the platform's own resolver.
  final MediaResolver? resolver;

  /// The in-browser clip decoder (WebCodecs) — required for a `Clip` to decode
  /// on web, ignored elsewhere. `fluvie_web_encoder` provides one; the type
  /// comes from `package:fluvie/rendering.dart`. Desktop needs none (it decodes
  /// through ffmpeg).
  final WebClipDecoder? clipDecoder;

  /// The safety gate for network media, from `package:fluvie/rendering.dart`;
  /// defaults to the provider's allowlist.
  final NetworkAllowlist? networkAllowlist;

  /// The longest side a clip decodes at in preview, or `null` for the source's
  /// own resolution. Bounds memory; does not affect timing.
  final int? maxClipEdge;

  /// Asset overlay shared with normal Flutter Image.asset widgets.
  final AssetBundle? assetBundle;

  /// Optional generative backend for generated visual elements.
  final GenerativeResolver? generative;

  /// Optional external snapshot backend.
  final SnapshotService? snapshotService;

  /// Optional audio beat analysis backend.
  final BeatDetectionService? beatDetector;

  /// Optional audio band analysis backend.
  final FrequencyAnalyzer? analyzer;

  @override
  State<PreviewMediaScope> createState() => _PreviewMediaScopeState();
}

class _PreviewMediaScopeState extends State<PreviewMediaScope> {
  MediaResolver? _resolver;
  CompositionSession? _session;
  final GlobalKey _compositionKey = GlobalKey(debugLabel: 'preview composition');
  final Completer<void> _firstMount = Completer<void>();
  PreviewClipFrames? _previewFrames;
  int _revision = 0;
  int _generation = 0;
  bool _decoding = false;
  bool _preparationFailed = false;
  int? _pendingFrame;
  Future<void> Function()? _release;
  Future<void>? _inFlightPrepare;
  Map<String, ui.FragmentProgram> _shaderPrograms = const {};
  Map<String, ui.Image> _colorLookups = const {};

  @override
  void initState() {
    super.initState();
    // Nothing awaits the warm-up: it publishes the resolver through setState
    // when it lands, and the placeholder covers the tree until then.
    widget.frames?.addListener(_frameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_firstMount.isCompleted) _firstMount.complete();
    });
    unawaited(_warmUp());
  }

  @override
  void didUpdateWidget(PreviewMediaScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.frames, widget.frames)) {
      oldWidget.frames?.removeListener(_frameChanged);
      widget.frames?.addListener(_frameChanged);
    }
    // The warm-up is keyed to the composition's media; a new composition needs a
    // fresh pass. Identical compositions (a rebuild) keep the warm resolver.
    if (identical(oldWidget.composition, widget.composition) &&
        identical(oldWidget.resolver, widget.resolver) &&
        identical(oldWidget.clipDecoder, widget.clipDecoder) &&
        oldWidget.maxClipEdge == widget.maxClipEdge &&
        identical(oldWidget.frames, widget.frames) &&
        identical(oldWidget.assetBundle, widget.assetBundle) &&
        identical(oldWidget.generative, widget.generative) &&
        identical(oldWidget.beatDetector, widget.beatDetector) &&
        identical(oldWidget.analyzer, widget.analyzer) &&
        identical(oldWidget.snapshotService, widget.snapshotService)) {
      return;
    }
    _teardown();
    _preparationFailed = false;
    setState(() => _resolver = null);
    unawaited(_warmUp());
  }

  @override
  void dispose() {
    widget.frames?.removeListener(_frameChanged);
    _teardown();
    super.dispose();
  }

  /// Releases an owned resolver and forgets it, so a rebuild or unmount never
  /// leaves decoded frames or a provider container alive.
  void _teardown() {
    _generation++;
    _session = null;
    _previewFrames = null;
    _pendingFrame = null;
    _releaseMedia();
    final lookups = _colorLookups;
    _shaderPrograms = const {};
    _colorLookups = const {};
    if (lookups.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final image in lookups.values) {
          image.dispose();
        }
      });
    }
  }

  void _releaseMedia() {
    final release = _release;
    final pending = _inFlightPrepare;
    _release = null;
    _resolver = null;
    if (release == null) return;
    // A resolver may still be extracting a frame. Retire it only when that
    // operation stops touching its cache, and after the old tree has unmounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(() async {
        try {
          await pending;
        } on Object {
          /* The active decode reports failures. */
        }
        await release();
      }());
    });
  }

  /// Runs the render's own pre-pass — images first (a clip is content-hashed
  /// there), then the clip probe and frame extraction — and publishes the
  /// resolver only once every frame paint will read is decoded and warm.
  ///
  /// A failure is never fatal: a preview that cannot decode its media still
  /// shows the composition, with each media element on its own fallback. It is
  /// reported (debug builds, non-fatal) rather than swallowed, because the
  /// symptom otherwise is a placeholder with no stated cause.
  Future<void> _warmUp() async {
    final generation = _generation;
    final composition = widget.composition;
    await _firstMount.future;
    if (!mounted || generation != _generation) return;
    final video = compositionVideo(composition);
    if (video == null) return;
    // Shaders warm first and independently of the media resolver: a shader over
    // a plain box declares no media, and a failure here must not cost the
    // preview its decoded clips.
    if (widget.warmEffects && widget.child != null) await _warmShaders(composition, generation);
    if (!mounted || generation != _generation) return;
    final scope = resolverScope(
      widget.resolver,
      networkAllowlist: widget.networkAllowlist,
      clipDecoder: widget.clipDecoder,
      clipDecodeMaxEdge: widget.maxClipEdge,
      // Preview owns its asynchronous bounded scrub cache. Capture drives the
      // separate streaming resolver synchronously from its frame pump.
      streamClipFrames: false,
      assetBundle:
          widget.assetBundle ?? context.getInheritedWidgetOfExactType<DefaultAssetBundle>()?.bundle,
    );
    PreviewClipFrames? preview;
    CompositionSession? preparedSession;
    try {
      if (widget.child == null) {
        final bundle =
            widget.assetBundle ??
            context.getInheritedWidgetOfExactType<DefaultAssetBundle>()?.bundle;
        final session = CompositionSession(
          composition: composition,
          resolver: scope.resolver,
          mountKey: _compositionKey,
          generative: widget.generative ?? const NoGenerativeResolver(),
          snapshotService: widget.snapshotService,
          beatDetector: widget.beatDetector,
          analyzer: widget.analyzer,
          loadCubeText: bundle == null ? bundleCubeText : bundle.loadString,
        );
        preparedSession = session;
        _session = session;
        Future<void> rebuild(Widget tree) async {
          if (!mounted || generation != _generation) {
            throw StateError('Preview preparation was superseded.');
          }
          setState(() {});
          await WidgetsBinding.instance.endOfFrame;
        }

        Future<T?> direct<T>(Future<T> Function() callback) => callback();
        final preparing = _inFlightPrepare = session.prepare(
          mount: rebuild,
          pump: () => rebuild(const SizedBox.shrink()),
          buildTree: () => session.mountTree(composition),
          runAsync: direct,
          warmEffects: widget.warmEffects,
        );
        await preparing;
        if (identical(_inFlightPrepare, preparing)) _inFlightPrepare = null;
        preview = session.previewFrames;
        if (widget.frames == null) {
          for (var frame = 1; frame < video.totalFrames; frame++) {
            await session.prepareFrame(frame);
          }
        } else {
          await session.prepareFrame(widget.frames!.value);
        }
      } else {
        await scope.resolver.preResolveAll(collectCompositionMedia(composition));
        if (widget.frames != null) {
          preview = PreviewClipFrames(scope.resolver, composition);
          await preview.initialize();
          await preview.prepare(widget.frames!.value);
        } else {
          await preResolveCompositionClips(
            composition: composition,
            resolver: scope.resolver,
            totalFrames: video.totalFrames,
          );
        }
      }
    } on Object catch (error, stack) {
      await scope.dispose();
      preparedSession?.dispose();
      if (mounted && generation == _generation) {
        setState(() {
          _session = null;
          _preparationFailed = true;
        });
        _reportWarmUpFailure(error, stack);
      }
      return;
    }
    // The tree may have gone away (or moved on to another composition) while the
    // decode ran; the resolver we just warmed is then ours to release.
    if (!mounted || generation != _generation || !identical(widget.composition, composition)) {
      await scope.dispose();
      preparedSession?.dispose();
      return;
    }
    // Release whatever is already published before taking its place: two
    // warm-ups can be in flight at once (the composition swapped away and back),
    // and overwriting _release would strand the earlier resolver's frames.
    _releaseMedia();
    setState(() {
      _resolver = scope.resolver;
      _previewFrames = preview;
      _revision++;
      _release = () async {
        await scope.dispose();
        preparedSession?.dispose();
      };
    });
    widget.onReady?.call(scope.resolver);
    _frameChanged();
  }

  void _frameChanged() {
    if (_previewFrames == null || widget.frames == null) return;
    _pendingFrame = widget.frames!.value;
    if (!_decoding) unawaited(_decodePending());
  }

  Future<void> _decodePending() async {
    _decoding = true;
    try {
      while (mounted && _pendingFrame != null) {
        final frame = _pendingFrame!;
        _pendingFrame = null;
        final preview = _previewFrames;
        final generation = _generation;
        if (preview == null) break;
        final preparing = _inFlightPrepare =
            _session?.prepareFrame(frame) ?? preview.prepare(frame);
        try {
          await preparing;
        } on Object catch (error, stack) {
          if (mounted && generation == _generation) _reportWarmUpFailure(error, stack);
          continue;
        } finally {
          if (identical(_inFlightPrepare, preparing)) _inFlightPrepare = null;
        }
        if (!mounted || generation != _generation) continue;
        setState(() => _revision++);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || generation != _generation) return;
          try {
            _session?.validateFrameResources();
          } on Object catch (error, stack) {
            _reportWarmUpFailure(error, stack);
          }
          preview.evict();
        });
      }
    } on Object catch (error, stack) {
      _reportWarmUpFailure(error, stack);
    } finally {
      _decoding = false;
      if (mounted && _pendingFrame != null && _previewFrames != null) unawaited(_decodePending());
    }
  }

  /// Compiles the composition's shader programs for the preview, reporting a
  /// failure the same non-fatal way a media failure is reported.
  ///
  /// A cold shader is not fatal either: the painter throws, Flutter catches it
  /// per paint and reports it, and the rest of the frame still draws — so the
  /// author sees the composition and is told which asset did not compile.
  Future<void> _warmShaders(Widget composition, int generation) async {
    try {
      final programs = await preLoadCompositionShaders(composition: composition);
      final lookups = await preBakeCompositionColorLookups(composition: composition);
      if (programs.isEmpty && lookups.isEmpty) return;
      if (!mounted || generation != _generation || !identical(widget.composition, composition)) {
        for (final image in lookups.values) {
          image.dispose();
        }
        return;
      }
      setState(() {
        _shaderPrograms = programs;
        _colorLookups = lookups;
      });
    } on Object catch (error, stack) {
      if (mounted && generation == _generation) _reportWarmUpFailure(error, stack);
    }
  }

  /// Reports a failed warm-up in debug builds without breaking the preview: the
  /// media falls back, but the author is told why rather than left staring at a
  /// placeholder. Release builds stay silent — a shipped app is not authoring.
  void _reportWarmUpFailure(Object error, StackTrace stack) {
    if (!mounted) return;
    if (widget.onError case final onError?) {
      onError(error);
      return;
    }
    if (!kDebugMode) return;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'fluvie',
        context: ErrorDescription(
          'pre-resolving media for a live preview. The composition still shows, '
          'but its clips paint their placeholder instead of real frames. A clip '
          'decodes through ffmpeg on desktop (it must be on PATH) or through '
          "fluvie_web_encoder's decoder passed to PreviewMediaScope(clipDecoder:) "
          'on web',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolver = _resolver;
    var tree = widget.child ?? widget.composition;
    if (widget.child == null) {
      tree =
          _session?.mountTree(tree) ??
          PreparationScope(
            preparing: !_preparationFailed,
            child: KeyedSubtree(key: _compositionKey, child: tree),
          );
      final preview = _previewFrames;
      if (preview != null) {
        tree = PreviewClipScope(ready: preview.ready, revision: _revision, child: tree);
      }
      final bundle = widget.assetBundle;
      if (bundle != null) tree = DefaultAssetBundle(bundle: bundle, child: tree);
      return tree;
    }
    if (_shaderPrograms.isNotEmpty) {
      tree = WarmShaderScope(programs: _shaderPrograms, child: tree);
    }
    if (_colorLookups.isNotEmpty) {
      tree = ColorLookupScope(lookups: _colorLookups, child: tree);
    }
    if (resolver == null) return tree;
    final preview = _previewFrames;
    if (preview != null) {
      tree = PreviewClipScope(ready: preview.ready, revision: _revision, child: tree);
    }
    return ImageResolverScope(resolver: resolver, child: tree);
  }
}
