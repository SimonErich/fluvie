import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:slides/editor/audio_preview_platform.dart';

part 'audio_preview_loading.dart';
part 'audio_preview_output.dart';

/// Program/source mono audition using the export's resolved timing and mix.
/// This is ephemeral state: solo, output and waveform caches never edit a spec.
final class AudioPreviewController extends ChangeNotifier {
  AudioPreviewController({
    required this.monitor,
    MediaResolver? mediaResolver,
    WebClipDecoder? clipDecoder,
    this.bytesFor,
    this.networkAllowlist,
    AudioPreviewPlatform? platform,
  }) : _platform = platform ?? createAudioPreviewPlatform(),
       _resolverScope = resolverScope(
         mediaResolver,
         networkAllowlist: networkAllowlist,
         clipDecoder: clipDecoder,
       ) {
    monitor.addListener(_mixChanged);
  }
  final AudioMonitorController monitor;
  final ResolverScope _resolverScope;
  MediaResolver get mediaResolver => _resolverScope.resolver;
  final Uint8List? Function(String sourceKey)? bytesFor;
  final NetworkAllowlist? networkAllowlist;
  final AudioPreviewPlatform _platform;
  final Map<String, PcmAudio> _pcm = {};
  final Map<String, Future<PcmAudio>> _pending = {};
  final Map<String, WaveformEnvelope> _envelopes = {};
  final Map<String, ClipMetadata> _metadata = {};
  List<AudioTrackView> _tracks = [];
  EditorDocument? _document;
  SlideTransport? _transport;
  int _absoluteOffset = 0;
  int _lastFrame = 0;
  int _epoch = 0;
  int _loadEpoch = 0;
  double _chunkEnd = -1;
  bool _disposed = false;
  bool _loading = false;
  bool _programLoading = false;
  bool _auditioning = false;
  String? _error;
  Map<String, WaveformEnvelope> get envelopes => Map.unmodifiable(_envelopes);
  Map<String, ClipMetadata> get clipMetadata => Map.unmodifiable(_metadata);
  String? get error => _error;
  bool get loading => _loading || _programLoading;
  bool get auditioning => _auditioning;

  /// Preview downmix is mono; export retains its selected channel format.
  String get channelLabel => 'Mono audition';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _fail(Object error) {
    if (!_disposed) {
      _error = error.toString();
      _notify();
    }
  }

  /// Binds the active clock; slide playback supplies its absolute scene offset.
  void bindTransport(SlideTransport transport, {int absoluteOffset = 0}) {
    if (identical(_transport, transport) && _absoluteOffset == absoluteOffset) return;
    unbindTransport();
    _transport = transport;
    _absoluteOffset = absoluteOffset;
    _lastFrame = transport.frame;
    transport.addListener(_stateChanged);
    transport.frames.addListener(_frameChanged);
    _stateChanged();
  }

  void unbindTransport() {
    _transport?.removeListener(_stateChanged);
    _transport?.frames.removeListener(_frameChanged);
    _transport = null;
    _cancelOutput();
  }

  /// Reloads mix facts only when render-affecting content changes.
  void updateDocument(EditorDocument document) {
    if (_document?.renderDigest == document.renderDigest) return;
    _document = document;
    _auditioning = false;
    _loading = false;
    _cancelOutput();
    unawaited(
      Future<void>.microtask(() async {
        if (!_disposed && identical(_document, document)) await _load(document);
      }),
    );
  }

  /// Retries source/decode failures without changing the document.
  void retry() {
    final document = _document;
    if (document != null) unawaited(_load(document));
  }

  Future<void> _disposeResources() async {
    await _platform.dispose();
    await _resolverScope.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadEpoch++;
    monitor.removeListener(_mixChanged);
    unbindTransport();
    unawaited(_disposeResources());
    _pcm.clear();
    _envelopes.clear();
    super.dispose();
  }
}
