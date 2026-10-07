import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show Video;
import 'package:fluvie/rendering.dart'
    show
        ColorLookupScope,
        WarmShaderScope,
        collectShaderAssets,
        preBakeCompositionColorLookups,
        preLoadCompositionShaders;

/// Warms the same shader and lookup resources as export before mounting
/// their composition. Progress and failures are visible in release builds;
/// retry never changes the document or hides a failed grade behind a success.
final class EffectWarmHost extends StatefulWidget {
  /// Warms resources for the composition before mounting its child.
  const EffectWarmHost({required this.composition, required this.child, super.key});

  /// The composition whose shader and lookup declarations are collected.
  final Widget composition;

  /// The rendered subtree covered by the warm resource scopes.
  final Widget child;

  @override
  State<EffectWarmHost> createState() => EffectWarmHostState();
}

/// Provides the settled resource future to the hidden preview read-back.
final class EffectWarmHostState extends State<EffectWarmHost> {
  Map<String, ui.FragmentProgram> _programs = const {};
  Map<String, ui.Image> _lookups = const {};
  bool _loading = true;
  Object? _error;
  Future<void> _ready = Future.value();

  /// Completes after the current resources are warm, or throws on failure.
  Future<void> get ready => _ready;

  /// Whether warmed content has already been mounted.
  bool get isReady => !_loading && _error == null;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(EffectWarmHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.composition, widget.composition)) _start();
  }

  void _start() {
    final composition = widget.composition;
    if (composition is Video &&
        collectShaderAssets(composition.scenes, overlays: composition.overlays).isEmpty) {
      final old = _lookups;
      _programs = const {};
      _lookups = const {};
      _loading = false;
      _error = null;
      _ready = Future.value();
      if (old.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final image in old.values) {
            image.dispose();
          }
        });
      }
      return;
    }
    _loading = true;
    _error = null;
    _ready = _warm(widget.composition);
    // The state renders the failure; callers awaiting ready still observe it.
    unawaited(_ready.catchError((Object _) {}));
  }

  Future<void> _warm(Widget composition) async {
    try {
      final programs = await preLoadCompositionShaders(composition: composition);
      final lookups = await preBakeCompositionColorLookups(composition: composition);
      if (!mounted || !identical(widget.composition, composition)) {
        for (final image in lookups.values) {
          image.dispose();
        }
        return;
      }
      final old = _lookups;
      setState(() {
        _programs = programs;
        _lookups = lookups;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final image in old.values) {
          image.dispose();
        }
      });
    } on Object catch (error) {
      if (mounted && identical(widget.composition, composition)) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    for (final image in _lookups.values) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null) {
      return ColoredBox(
        color: const Color(0xFF15171B),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _loading ? 'Preparing effects…' : 'Effects could not load: $_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
                  ),
                ),
                if (_error != null)
                  Semantics(
                    button: true,
                    label: 'Retry loading effects',
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.enter): () => setState(_start),
                        const SingleActivator(LogicalKeyboardKey.space): () => setState(_start),
                      },
                      child: Focus(
                        child: GestureDetector(
                          onTap: () => setState(_start),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'Retry',
                              style: TextStyle(color: Color(0xFFB9AEFF), fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    var tree = widget.child;
    if (_programs.isNotEmpty) tree = WarmShaderScope(programs: _programs, child: tree);
    if (_lookups.isNotEmpty) tree = ColorLookupScope(lookups: _lookups, child: tree);
    return tree;
  }
}
