import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/colour/scope_data.dart';
import 'package:obers_ui/obers_ui.dart';

export 'scope_data.dart';

part 'colour_scope_painter.dart';

/// Throttles actual preview read-back, coalesces scrub requests and caches
/// by render digest plus frame. No second composition or document mutation.
final class ColourScopesController extends ChangeNotifier {
  /// Caps work at ten settled frames per second by default.
  ColourScopesController({this.interval = const Duration(milliseconds: 100)});

  /// Minimum delay between read-back computations.
  final Duration interval;
  final _cache = <String, ScopeData>{};
  Timer? _timer;
  ({String key, Future<ScopeData> Function() read})? _pending;
  bool _busy = false;
  bool _disposed = false;
  String? _wantedKey;
  ScopeData? _data;
  String? _error;

  /// The most recently settled frame, or null before the first capture.
  ScopeData? get data => _data;

  /// The latest read-back failure, cleared by a successful frame.
  String? get error => _error;

  /// Queues the latest settled-frame request; repeated keys hit the cache.
  void request(String key, Future<ScopeData> Function() read) {
    if (_disposed) return;
    _wantedKey = key;
    if (_cache[key] case final ScopeData cached) {
      _pending = null;
      if (!identical(_data, cached) || _error != null) {
        _data = cached;
        _error = null;
        notifyListeners();
      }
      return;
    }
    _pending = (key: key, read: read);
    if (!_busy) _timer ??= Timer(interval, _run);
  }

  Future<void> _run() async {
    _timer = null;
    final request = _pending;
    if (_disposed || request == null) return;
    _pending = null;
    _busy = true;
    try {
      final result = await request.read();
      if (_disposed) return;
      _cache[request.key] = result;
      while (_cache.length > 12) {
        _cache.remove(_cache.keys.first);
      }
      if (_wantedKey == request.key) {
        _data = result;
        _error = null;
        _pending = null;
        notifyListeners();
      }
    } on StaleScopeFrame {
      // A newer preview replaced the queued frame before read-back.
    } on Object catch (error) {
      if (!_disposed && _wantedKey == request.key) {
        _error = 'Scopes unavailable: $error';
        notifyListeners();
      }
    } finally {
      _busy = false;
      if (!_disposed && _pending != null) _timer ??= Timer(interval, _run);
    }
  }

  /// Samples the existing canvas boundary at a bounded resolution.
  static Future<ScopeData> capture(RenderRepaintBoundary boundary) async {
    final ratio = (320 / boundary.size.width).clamp(0.01, 1.0);
    final image = await boundary.toImage(pixelRatio: ratio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      if (data == null) throw StateError('The preview returned no pixels');
      return ScopeData.fromRgba(data.buffer.asUint8List(), image.width, image.height);
    } finally {
      image.dispose();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _cache.clear();
    super.dispose();
  }
}

/// Histogram, luminance waveform and chroma vectorscope of the preview.
final class ColourScopes extends StatefulWidget {
  /// Displays the controller’s current histogram, waveform or vectorscope.
  const ColourScopes({required this.controller, super.key});

  /// The sampled preview data source.
  final ColourScopesController controller;
  @override
  State<ColourScopes> createState() => _ColourScopesState();
}

final class _ColourScopesState extends State<ColourScopes> {
  String _mode = 'Histogram';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OiLabel.body('Scopes'),
        OiSelect<String>(
          value: _mode,
          options: [
            for (final mode in ['Histogram', 'Waveform', 'Vectorscope'])
              OiSelectOption(value: mode, label: mode),
          ],
          onChanged: (mode) {
            if (mode != null) setState(() => _mode = mode);
          },
        ),
        if (widget.controller.error case final String error)
          OiLabel.small(error)
        else if (widget.controller.data case final ScopeData data) ...[
          Semantics(
            label: '$_mode from ${data.samples} preview pixels',
            child: SizedBox(
              height: 150,
              child: CustomPaint(
                painter: _ScopePainter(
                  data,
                  _mode,
                  context.colors.accent.base,
                  context.colors.borderSubtle,
                ),
              ),
            ),
          ),
          OiLabel.small(
            _mode == 'Histogram'
                ? 'RGB counts · shadows → highlights'
                : _mode == 'Waveform'
                ? 'Horizontal position · 0–100% luminance'
                : 'Cb horizontal · Cr vertical · centre is neutral',
          ),
        ] else
          const OiLabel.small('Waiting for a settled preview frame…'),
      ],
    ),
  );
}

/// Internal cancellation when the canvas has moved to a newer frame.
final class StaleScopeFrame implements Exception {
  /// Cancels a queued read-back whose frame has already changed.
  const StaleScopeFrame();
}
